// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

/// A specialised architectural configuration interface that defines the behavioural
/// constraints, security protocols, and reactive strategies for a [TissueQueue].
///
/// [TissueQueueNucleus] acts as the **Stateless Blueprint** (the "DNA") for
/// reactive, double‑ended queues within the `cell_tissue` ecosystem. It extends
/// the core [TissueNucleus] contract to provide specialised support for
/// FIFO (First‑In‑First‑Out) and LIFO (Last‑In‑First‑Out) operations while
/// ensuring thread‑safe, atomic state transitions through the **Conactive Model**.
///
/// ### When to use
/// You might reference this type when you need to:
/// - Pass a pre‑configured nucleus to [TissueQueue.fromNucleus] to reuse a
///   validated queue blueprint.
/// - Extend a custom queue implementation that needs to override the default
///   behaviour.
/// - Debug why a queue is behaving in a certain way – inspect its nucleus to see
///   the `capacity`, `testRule`, etc.
///
/// You never implement this interface directly. It is used internally by the
/// framework to configure a [TissueQueue]. You interact with it indirectly when
/// creating a queue via [TissueQueue] or [TissueQueue.create].
///
/// The most common way to get a nucleus is to let the framework create one for
/// you when you use `TissueQueue()`. You rarely need to construct one manually.
///
/// ### How it works
/// - The nucleus holds all **stateless** configuration: the [receptor]
///   (how mutation commands are processed), the [testRule] (validation logic),
///   the [context] (security tier), and the [synapses] (propagation behaviour).
/// - It also determines the **physical storage strategy** ([containerType] always
///   [Container.queue]) and the [capacity] (maximum size, or -1 for unbounded).
/// - A nucleus can be **evolved** (via `evolve`) to create a deputy – a
///   restricted view that shares the same data but applies different rules.
/// - The nucleus is immutable; once created, it cannot be changed.
///
/// ### Non‑obvious
/// - The [capacity] is **structural** – it is fixed at creation and inherited
///   by all deputies. You cannot change the capacity of a queue through a deputy.
/// - The nucleus is a **flyweight** – many queues can share the same nucleus
///   without duplicating memory.
/// - The [clone] getter creates a fresh copy of the nucleus with its own
///   [Lock] and [Synapses]. This is used internally when you create a new queue
///   from an already‑activated nucleus to avoid sharing locks.
/// - The `principal` chain allows hierarchical inheritance – a deputy nucleus
///   can override only specific properties (like `testRule`) while inheriting
///   the rest from its principal.
///
/// ### Example: Reusing a validated queue blueprint
/// ```dart
/// final validNucleus = TissueQueueNucleus.create<String>(
///   capacity: 10,
///   testRule: TestTissue<String>((v) => v.isNotEmpty),
/// );
/// final queue1 = TissueQueue.fromNucleus(validNucleus);
/// final queue2 = TissueQueue.fromNucleus(validNucleus); // shares logic, not data
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements held within the associated [TissueQueue].
///
/// See also:
/// - [TissueQueue] – the reactive queue instance governed by this nucleus.
/// - [TissueReceptor] – the engine that processes mutation signals.
/// - [TestTissue] – the validation logic for collection elements.
abstract interface class TissueQueueNucleus<E> implements TissueNucleus<E> {

  /// The primary architectural factory for creating a [TissueQueueNucleus],
  /// defining the foundational "Reactive DNA" and behavioural blueprint for
  /// a [TissueQueue].
  ///
  /// This factory is the standard entry point for initialising the governance
  /// layer of a reactive, double‑ended queue. It utilises the **Flyweight
  /// Record Pattern** to internalise the provided parameters into a compact,
  /// deeply immutable configuration record, ensuring that even in systems
  /// managing thousands of message buffers or event loops, the memory
  /// overhead remains negligible.
  ///
  /// ### When to use
  /// Use this when you are building a custom queue configuration from scratch.
  /// For most use cases, the simpler [TissueQueue] factory is sufficient.
  ///
  /// ### How it works
  /// - You provide the [capacity] (maximum size, or -1 for unbounded) and
  ///   optional governance parameters.
  /// - The framework creates a nucleus record that stores only non‑default
  ///   properties (memory optimisation).
  /// - The resulting nucleus can be used to instantiate multiple queues that
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
  /// - [capacity]: The maximum number of elements permitted. `-1` means unbounded.
  /// - [bind]: Optional upstream [Cell] to observe.
  /// - [context]: Operational environment (default: [Context.system]).
  /// - [receptor]: Mutation command processor (default: pass‑through).
  /// - [testRule]: Validation gatekeeper (default: allow all).
  /// - [synapses]: Propagation configuration (default: enabled).
  /// - [user]: Optional metadata for custom logic.
  ///
  /// ### Returns:
  /// A concrete [TissueQueueNucleus<E>] implementation tailored to the
  /// provided reactive blueprint.
  factory TissueQueueNucleus({
    int? capacity,

    Cell? bind,
    Context context,
    TissueReceptor<E,TissueQueue<E>> receptor,
    TestTissue<E,TissueQueue<E>> testRule,
    Synapses synapses,
    Record? user
  }) = _TissueQueueNucleus<E,TissueQueue<E>>;

  /// Creates a derived [TissueQueueNucleus] by mutating or extending
  /// an existing [principal] configuration.
  ///
  /// This factory is the primary architectural implementation of **Prototypal
  /// Inheritance** and **Behavioural Shadowing** within the queue ecosystem.
  /// It allows for the creation of specialised "Deputy" configurations that
  /// logically inherit the structural DNA and baseline rules of a [principal]
  /// while selectively overriding specific operational traits.
  ///
  /// ### When to use
  /// This is the engine behind the `deputy()` method on [TissueQueue]. You
  /// rarely call it directly. Use it when you need a restricted view of a queue
  /// that shares the same storage but applies different validation, context, or
  /// capacity.
  ///
  /// ### How it works
  /// - The new nucleus inherits all properties from [principal] unless
  ///   explicitly overridden.
  /// - You can override the [capacity], [testRule] (to narrow permissions),
  ///   [context] (to change authority), [receptor] (to transform mutations),
  ///   or [synapses].
  /// - The [container] strategy is always inherited (it remains a [Queue]).
  /// - The new nucleus shares the same [Lock] and physical storage as the
  ///   principal (unless you provide an [override] that introduces a new lock).
  ///
  /// ### Non‑obvious
  /// - The [capacity] override allows you to create a "Sub‑Queue" deputy that
  ///   has a stricter resource limit than its principal, useful for partitioning
  ///   a shared system‑wide buffer into smaller, scoped consumer pools.
  /// - The [override] parameter allows you to layer a complete pre‑configured
  ///   nucleus on top of the principal.
  /// - The resulting nucleus does **not** copy the principal's data – it shares
  ///   it via the inheritance chain.
  ///
  /// ### Example
  /// ```dart
  /// final principal = TissueQueueNucleus.create<String>(capacity: 10);
  /// final readOnlyNucleus = TissueQueueNucleus.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  ///   capacity: 5, // narrower capacity for this deputy
  /// );
  /// final readOnlyQueue = TissueQueue.fromNucleus(readOnlyNucleus);
  /// ```
  ///
  /// ### Parameters:
  /// - [capacity]: Optional override for the maximum element threshold.
  /// - [bind]: Optional override for the upstream cell.
  /// - [context]: Optional override for the execution context.
  /// - [receptor]: Optional override for the mutation processor.
  /// - [testRule]: Optional override for the validation rule.
  /// - [synapses]: Optional override for propagation behaviour.
  /// - [override]: Optional. A complete nucleus whose properties are layered
  ///   on top of the principal.
  /// - [principal]: **Required**. The base nucleus to extend.
  ///
  /// ### Returns:
  /// A new [TissueQueueNucleus<E>] instance that acts as a specialised
  /// behavioral layer over the [principal].
  factory TissueQueueNucleus.evolve({
    int? capacity,

    Cell? bind,
    Context? context,
    TissueReceptor<E, TissueQueue<E>>? receptor,
    TestTissue<E, TissueQueue<E>>? testRule,
    Synapses? synapses,

    TissueQueueNucleus<E>? override,
    required TissueQueueNucleus<E> principal
  }) = _TissueQueueNucleus<E,TissueQueue<E>>.evolve;

  /// A highly configurable static utility factory that produces a type‑safe
  /// [TissueQueueNucleus] configuration for a specific element type [E]
  /// and a specialised [TissueQueue] interface [C].
  ///
  /// This method serves as the preferred architectural entry point for
  /// constructing the **Behavioural DNA** of a reactive queue. It facilitates
  /// the precise assembly of governance rules, operational contexts, and
  /// physical storage strategies, ensuring that all components are strictly
  /// aligned with the target interface [C].
  ///
  /// ### When to use
  /// Use this when you are building a custom queue implementation that extends
  /// [TissueQueue] and you want to ensure type safety between the queue and its
  /// receptor/testRule.
  ///
  /// ### How it works
  /// - It creates a nucleus with the provided parameters, inferring defaults
  ///   where omitted.
  /// - If a [principal] is provided, it creates an evolved nucleus that
  ///   inherits from that principal.
  /// - The [capacity] parameter establishes the resource boundary.
  /// - The [container] parameter defaults to [Container.queue].
  ///
  /// ### Non‑obvious
  /// - The [forceLock] flag, when `true`, allows sharing the principal's lock.
  ///   This is typically used for deputies to maintain a single atomic boundary.
  /// - The [capacity] is stored in the `others` segment of the record, keeping
  ///   the core nucleus compact.
  ///
  /// ### Parameters:
  /// - [capacity]: The maximum element threshold (use -1 for unbounded).
  /// - [bind]: Optional upstream cell.
  /// - [context]: Optional execution context.
  /// - [receptor]: Optional mutation processor.
  /// - [testRule]: Optional validation rule.
  /// - [synapses]: Optional propagation configuration.
  /// - [container]: Optional storage strategy (defaults to [Container.queue]).
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns:
  /// A nucleus instance strictly configured for the specified element and
  /// tissue types.
  static TissueQueueNucleusBase<E,C> create<E,C extends TissueQueue<E>>({
    int? capacity,

    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueQueueNucleusBase<E,C>? principal
  }) {

    if (principal != null) {
      final local = TissueNucleusBase.local<E,Queue<E>,C>(
          container: container,
          bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock, user: user,
          others: capacity != null ? (capacity: capacity) : null
      );
      return _TissueQueueNucleus<E,C>.fromRecord(
          (mask: local, principal: principal)
      );
    }

    return _TissueQueueNucleus<E,C>(
        capacity: capacity,

        bind: bind,
        context: context ?? Context.system,
        receptor: receptor ?? TissueReceptor.passThrough,
        testRule: testRule ?? TestTissue.allowAll,
        synapses: synapses ?? Synapses.enabled,
        user: user,
        forceLock: forceLock
    );

  }

  /// Creates an independent, decoupled clone of the current [TissueQueueNucleus]
  /// template.
  ///
  /// This getter implements the **Prototype Pattern** specifically for reactive
  /// queue configurations. It generates a peer instance that replicates the
  /// structural logic and FIFO/Double‑Ended operational constraints of the
  /// original without sharing its internal lifecycle state, observer registry,
  /// or synchronisation primitives.
  ///
  /// ### When to use
  /// You rarely need to call this directly. It is used internally when a nucleus
  /// needs to be cloned to avoid sharing locks between independent queues.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType] (always [Container.queue]).
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a queue instance.
  ///
  /// ### Non‑obvious
  /// - The clone does **not** share the same `principal` – it is a root nucleus
  ///   (no parent). This means it does not inherit from the original.
  /// - Cloning is a zero‑copy operation for the logic – the logic is shared
  ///   via the flyweight record, but the state (lock, synapses) is new.
  ///
  /// ### Returns:
  /// A new [TissueQueueNucleus<E>] instance with identical behavioural
  /// logic and storage strategy, but an isolated lifecycle and an
  /// independent synchronisation lock.
  @override
  TissueQueueNucleus<E> get clone;

  /// Retrieves the physical storage strategy ([Container]) defining the
  /// double‑ended operational semantics for the [TissueQueue].
  ///
  /// This property identifies the specialised data structure strategy—specifically
  /// [Container.queue]—that holds the actual elements [E]. It ensures that the
  /// resulting reactive collection behaves as a high‑performance, double‑ended
  /// buffer (supporting O(1) operations at both the head and tail).
  ///
  /// ### When to use
  /// Read this to confirm that the storage is indeed a queue. This is mostly
  /// informational.
  ///
  /// ### How it works
  /// - The value is resolved by walking up the principal chain if not defined
  ///   locally.
  /// - It always returns [Container.queue] for a queue nucleus.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed and cannot be changed
  ///   through a deputy. A deputy cannot change a queue into a different
  ///   collection type.
  @override
  Container get containerType;

  /// Retrieves the maximum element threshold ([capacity]) defined for this
  /// queue's operational domain.
  ///
  /// The [capacity] property is a critical component of the **Governance Layer**
  /// for [TissueQueue]. It defines the logical boundary for the queue's size,
  /// acting as a primary input for the [TestTissue] gatekeeper and the
  /// [TissueReceptor] to prevent buffer overflows or memory exhaustion in
  /// high‑frequency streaming scenarios.
  ///
  /// ### When to use
  /// Read this to know if the queue is bounded and what the limit is. This is
  /// useful for conditional UI logic (e.g., showing a "queue full" indicator)
  /// or for debugging.
  ///
  /// ### How it works
  /// - The capacity is resolved by walking up the principal chain if not
  ///   defined locally.
  /// - It defaults to `-1` (unbounded) if no capacity is set.
  ///
  /// ### Non‑obvious
  /// - The capacity is a **structural** property – it is fixed at creation and
  ///   inherited by all deputies. You cannot change the capacity of a queue
  ///   through a deputy unless you explicitly override it at creation.
  /// - The capacity is used for **backpressure regulation** – when the queue
  ///   is full, `add` operations may drop the oldest element or reject the new
  ///   one, depending on the specific `TissueQueue` implementation.
  int get capacity;

}

/// A reactive, high‑performance, and synchronised implementation of a
/// **Double‑Ended Queue (Deque)** that adheres to the standard Dart [Queue] contract.
///
/// [TissueQueue] serves as the primary bridge between traditional imperative
/// data structures and the **Conactive Model**. It provides a robust, thread‑safe
/// buffer where every modification—whether inserting at the head, removing
/// from the tail, or clearing the collection—is treated as a formal reactive
/// event. This allows the queue to be observed, validated, and synchronised
/// across the entire cell network.
///
/// ### When to use
/// Use a [TissueQueue] whenever you need a FIFO (or double‑ended) buffer that:
/// - Must be observable (UI updates automatically on changes).
/// - Must enforce invariants (e.g., max size, element type).
/// - Must be shared between components with different permissions (via deputies).
/// - Must participate in the reactive graph as a first‑class cell.
/// - Requires high‑performance add/remove at both ends (O(1)).
///
/// Most of the time, you create a [TissueQueue] using the [TissueQueue] factory,
/// optionally providing a [capacity] for bounded queues and a [testRule] for
/// validation:
/// ```dart
/// final queue = TissueQueue<int>(capacity: 10);
/// final validated = TissueQueue<String>(
///   testRule: TestTissue<String>((v) => v.isNotEmpty),
/// );
/// ```
///
/// ### How it works
/// - Internally, it uses a [TissueQueueNucleus] to govern behaviour and a
///   [Container.queue] for physical storage (a Dart `Queue<E>`).
/// - Every mutation (e.g., `add`, `addFirst`, `removeLast`, `clear`) goes
///   through a validation pipeline ([testRule]) and emits a [TissueEvent].
/// - The queue is thread‑safe via its internal [Lock].
/// - It can be **deputised** to create restricted views (read‑only, scoped
///   authority, bounded sub‑queues, etc.) that share the same storage.
/// - It supports both unbounded and bounded capacities (backpressure).
/// - It automatically links child [Cell]s when they are added, enabling
///   "bubbling" of internal changes.
///
/// ### Non‑obvious
/// - Equality (`==`) is based on the underlying queue's content and identity,
///   so `queue1 == queue2` works like a normal Dart queue.
/// - The [async] getter returns a [ModifiableQueueAsync] for `Future`‑based
///   operations, useful for network callbacks or background tasks.
/// - The `unmodifiable` getter is **not a snapshot** – it's a live view that
///   stays in sync with the source.
/// - Bounded queues (capacity >= 0) will drop the oldest element when a new
///   element is added and the queue is full (circular buffer behaviour).
/// - The [modifiable] getter returns the list of functions that can be invoked
///   via `apply`. For read‑only deputies, this list is empty.
///
/// ### Example: Basic usage
/// ```dart
/// final queue = TissueQueue<String>();
/// queue.add('A');
/// queue.add('B');
/// print(queue.removeFirst()); // 'A'
///
/// // Listen for changes
/// queue.listen((event) {
///   if (event is ElementAddedEvent<String>) {
///     print('Added: ${event.payload}');
///   }
/// });
/// queue.add('C'); // prints "Added: C"
/// ```
///
/// ### Example: Bounded queue (backpressure)
/// ```dart
/// final bounded = TissueQueue<int>(capacity: 3);
/// bounded.addAll([1, 2, 3]);
/// bounded.add(4); // drops the oldest (1) – queue now contains [2, 3, 4]
/// ```
///
/// ### Example: Validation
/// ```dart
/// final validQueue = TissueQueue<int>(
///   testRule: TestTissue<int>((v) => v >= 0),
/// );
/// validQueue.add(5); // allowed
/// validQueue.add(-1); // rejected – no event emitted
/// ```
///
/// ### Example: Read‑only deputy for UI
/// ```dart
/// final source = TissueQueue<String>();
/// final uiView = source.deputy(testRule: TestTissue.readOnly);
/// // uiView can be safely passed to a widget tree
/// // Changes to source are reflected in uiView automatically
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements held within the queue.
///
/// See also:
/// - [Tissue] – the base interface for all reactive collections.
/// - [TissueQueueNucleus] – the blueprint and configuration for the queue.
/// - [UnmodifiableTissueQueue] – a read‑only deputy variant.
abstract interface class TissueQueue<E> implements Tissue<E>, Queue<E> {

  @override
  TissueQueueNucleus<E> get _nucleus;

  /// The primary architectural factory for instantiating a [TissueQueue],
  /// creating a reactive, double‑ended buffer governed by the **Conactive Model**.
  ///
  /// This factory serves as the standard entry point for materialising a
  /// synchronised queue that participates in the `cell` framework's
  /// high‑fidelity data‑flow graph. It orchestrates the relationship between
  /// the logical governance layer (the [Nucleus]) and the physical storage
  /// layer, ensuring that every mutation—from basic enqueuing to complex
  /// buffer rotations—is atomic, validated, and observable.
  ///
  /// ### When to use
  /// Use this when you need a basic reactive queue with default behaviour.
  /// For more control (e.g., custom storage, context, or governance), use
  /// [TissueQueue.create] or [TissueQueue.fromNucleus].
  ///
  /// ### How it works
  /// - You provide an optional [capacity] (default unbounded) and optional
  ///   governance parameters.
  /// - The queue is created and automatically linked to any child cells.
  ///
  /// ### Parameters:
  /// - [capacity]: Maximum number of elements (unbounded if -1 or omitted).
  /// - [bind]: Optional upstream [Cell] for reactive dependency.
  /// - [context]: Operational environment (default: [Context.system]).
  /// - [receptor]: [TissueReceptor] for processing mutations.
  /// - [testRule]: [TestTissue] for validating changes.
  /// - [synapses]: [Synapses] configuration for broadcasting.
  ///
  /// ### Returns:
  /// A new [TissueQueue<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final queue = TissueQueue<int>(capacity: 10);
  /// ```
  factory TissueQueue({
    int? capacity,

    Cell? bind,
    Context context,
    TissueReceptor<E,TissueQueue<E>> receptor,
    TestTissue<E,TissueQueue<E>> testRule,
    Synapses synapses,
  }) = _TissueQueue<E,TissueQueue<E>>;

  /// Factory constructor to create a new, pre‑populated [TissueQueue] from an
  /// [Iterable] of elements.
  ///
  /// This constructor serves as a high‑level utility for materialising a
  /// reactive, double‑ended buffer that begins its lifecycle with an initial
  /// population of data. It ensures that the transition from a standard Dart
  /// [Iterable] to a synchronised **Conactive** node is performed atomically,
  /// securely, and within the framework's governance rules.
  ///
  /// ### When to use
  /// Use this when you already have an iterable of data and want to turn it
  /// into a reactive queue in one step.
  ///
  /// ### How it works
  /// - It creates a nucleus (with the provided parameters) and then ingests
  ///   the [elements] atomically under a lock.
  /// - Any elements that are [Cell]s are automatically linked to the queue.
  ///
  /// ### Parameters:
  /// - [elements]: The initial data.
  /// - [capacity], [bind], [context], [receptor], [testRule], [synapses] as
  ///   in the default constructor.
  ///
  /// ### Example
  /// ```dart
  /// final queue = TissueQueue.of([1, 2, 3], capacity: 10);
  /// ```
  factory TissueQueue.of(Iterable<E> elements, {
    int? capacity,

    Cell? bind,
    Context context,
    TissueReceptor<E,TissueQueue<E>> receptor,
    TestTissue<E,TissueQueue<E>> testRule,
    Synapses synapses,
  }) = _TissueQueue<E,TissueQueue<E>>.of;

  /// Primary architectural factory for materialising a [TissueQueue] from an
  /// existing [TissueQueueNucleus] (the "Reactive DNA").
  ///
  /// This constructor is the preferred entry point for the **Blueprint‑First
  /// Initialisation** pattern. It decouples the definition of the queue's
  /// governance—including its capacity, security rules, and command processing—
  /// from the instantiation of the reactive node itself.
  ///
  /// ### When to use
  /// - You have a reusable nucleus (e.g., a "ValidatedQueue" blueprint).
  /// - You are building a custom queue implementation that needs a specific
  ///   nucleus configuration.
  /// - You are restoring a queue from a serialised state where the nucleus is
  ///   already constructed.
  ///
  /// ### How it works
  /// - The queue adopts the nucleus's rules, context, and receptor.
  /// - If [elements] are provided, they are ingested atomically and validated
  ///   against the nucleus's [testRule].
  ///
  /// ### Example
  /// ```dart
  /// final nucleus = TissueQueueNucleus.create<String>(
  ///   capacity: 10,
  ///   testRule: TestTissue<String>((v) => v.isNotEmpty),
  /// );
  /// final queue = TissueQueue.fromNucleus(nucleus);
  /// ```
  ///
  /// ### Parameters:
  /// - [nucleus]: The blueprint to use.
  /// - [elements]: Optional initial data.
  ///
  /// ### Returns:
  /// A concrete [TissueQueue<E>] instance.
  factory TissueQueue.fromNucleus(TissueQueueNucleus<E> nucleus, {Iterable<E>? elements})
  = _TissueQueue<E,TissueQueue<E>>.fromNucleus;

  /// A high‑fidelity architectural factory for creating a **Deeply Immodifiable
  /// Reactive View** (Deputy) of an existing [TissueQueue].
  ///
  /// This constructor is the low‑level version of the `.unmodifiable` getter.
  /// You almost never call it directly – use `queue.unmodifiable` instead.
  ///
  /// ### When to use
  /// Use this when you need to share a queue with code that should only read
  /// data, never write it. For example, passing a queue to a UI widget.
  ///
  /// ### How it works
  /// - It creates a read‑only deputy that shares the same storage and lock as
  ///   the [bind] source.
  /// - It applies `TestTissue.readOnly` and optionally projects child cells.
  /// - The view is live and stays in sync with the source.
  ///
  /// ### Parameters
  /// - [bind]: The source queue to mirror.
  /// - [context]: Optional override for the execution context.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A read‑only [TissueQueue<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueQueue<int>();
  /// final readOnly = TissueQueue.unmodifiable(source);
  /// // readOnly.add(1); // blocked
  /// source.add(1); // readOnly reflects the change
  /// ```
  factory TissueQueue.unmodifiable(TissueQueue<E> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissueQueue<E,TissueQueue<E>>.view;

  /// A high‑level, comprehensive static factory for orchestrating the assembly
  /// and instantiation of a [TissueQueueBase], serving as the primary
  /// "Assembly Line" for reactive, double‑ended buffers.
  ///
  /// This method is the preferred architectural entry point for constructing
  /// [TissueQueue] instances that require precise behavioural configuration,
  /// security scoping, or specialised storage strategies. It streamlines the
  /// process by simultaneously defining the queue's governance (its "DNA") and
  /// initialising the live reactive node within the **Conactive** data‑flow graph.
  ///
  /// ### When to use
  /// Use this when the simple [TissueQueue] factory is insufficient, and you
  /// need to:
  /// - Specify a custom storage strategy ([container]).
  /// - Provide a custom [receptor] or [testRule] with full type safety.
  /// - Extend an existing nucleus via [principal].
  ///
  /// ### How it works
  /// - It builds a nucleus using [TissueQueueNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the queue from that nucleus, optionally ingesting
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
  /// - [container]: Optional storage strategy (defaults to [Container.queue]).
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns:
  /// A concrete [TissueQueueBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final queue = TissueQueue.create<int, TissueQueue<int>>(
  ///   container: Container.queue,
  ///   capacity: 5,
  ///   elements: [1, 2, 3],
  ///   testRule: TestTissue<int>((v) => v > 0),
  /// );
  /// ```
  static TissueQueueBase<E,C> create<E,C extends TissueQueue<E>>({
    Iterable<E>? elements,

    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueQueueNucleusBase<E,C>? principal
  }) {
    final nucleus = TissueQueueNucleus.create<E,C>(
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
    return _TissueQueue<E,C>.fromNucleus(nucleus, elements: elements);

  }

  /// Adds value at the end of the queue.
  @override
  void add(E value);

  /// Adds all values [iterable] at the end of the queue.
  @override
  void addAll(Iterable<E> iterable);

  /// Adds value at the beginning of the queue.
  @override
  void addFirst(E value);

  /// Adds value at the end of the queue.
  @override
  void addLast(E value);

  /// Clears the queue.
  @override
  void clear();

  /// Removes the first occurrence of [value] from the queue.
  @override
  bool remove(Object? value);

  /// Removes the first element from the queue.
  @override
  E removeFirst();

  /// Removes the last element from the queue.
  @override
  E removeLast();

  /// Removes all elements that satisfy the [test] condition.
  @override
  void removeWhere(bool Function(E element) test);

  /// Retains all elements that satisfy the [test] condition.
  @override
  void retainWhere(bool Function(E element) test);

  /// Creates a delegated view (deputy) of this queue with specialised behavioural,
  /// security, and validation logic.
  ///
  /// The [deputy] method is a fundamental implementation of the **Deputy Pattern**
  /// within the double‑ended reactive ecosystem. It allows for the instantiation
  /// of a derived [TissueQueue] that remains physically anchored to the same
  /// underlying storage as the original (principal) queue, but operates under a
  /// distinct layer of governance, validation rules, and execution context.
  ///
  /// ### When to use
  /// Use this when you need a restricted view of the queue:
  /// - Read‑only view: `queue.deputy(testRule: TestTissue.readOnly)`
  /// - Scoped authority: `queue.deputy(context: DeputyContext.delegate(...))`
  /// - Temporary access: `queue.deputy(ephemeralPolicy: ...)`
  /// - Bounded sub‑queue: `queue.deputy(capacity: 5)` (if the nucleus allows)
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
  /// - The deputy can also override the [capacity] (if the underlying nucleus
  ///   supports it) to create a bounded view of an unbounded queue.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueQueue<String>();
  /// final readOnly = await source.deputy(testRule: TestTissue.readOnly);
  /// // readOnly.add('A'); // blocked
  /// source.add('A'); // readOnly reflects the change
  /// ```
  @override
  FutureOr<TissueQueue<E>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  /// Returns a read‑only, reactive projection (Deputy) of this [TissueQueue].
  ///
  /// This getter provides a safe, immutable interface to the queue's data
  /// while maintaining a live, synchronised connection to the underlying
  /// source of truth.
  ///
  /// ### When to use
  /// Use this when you need to share the queue with components that should
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
  /// A read‑only [TissueQueue<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueQueue<int>();
  /// final readOnly = source.unmodifiable;
  /// // readOnly.add(1); // blocked
  /// source.add(1);
  /// print(readOnly.length); // 1 (live update)
  /// ```
  @override
  TissueQueue<E> get unmodifiable;

  /// Creates an async variant for [modifiable] operations
  @override
  ModifiableQueueAsync<E> get async;

  /// Provides a view of this queue as a queue of R instances, if necessary.
  @override
  Queue<R> cast<R>();

}

/// A specialised architectural interface for a **Deeply Immodifiable, Reactive
/// Double‑Ended Queue (Deque)**.
///
/// [UnmodifiableTissueQueue] represents a "Read‑Only Lens" or "Security
/// Shadow" within the `cell_tissue` ecosystem. It adheres to the full
/// [TissueQueue] and Dart [Queue] contracts, but structurally and logically
/// prohibits all direct state‑altering operations (e.g., `addFirst`, `removeLast`,
/// `clear`).
///
/// ### When to use
/// Use an unmodifiable queue when you need to share a queue with a component
/// that should **observe** changes but **never** initiate them. Common
/// scenarios include:
/// - Passing a queue to a UI widget that only renders data.
/// - Exposing internal state to a logger or analytics module.
/// - Providing a safe view to a plugin or sandboxed code.
/// - Implementing a "read‑only" API for external consumers.
///
/// You never implement this interface directly. You obtain an instance by
/// calling the `.unmodifiable` getter on a [TissueQueue]:
/// ```dart
/// final source = TissueQueue<int>();
/// final readOnly = source.unmodifiable; // UnmodifiableTissueQueue<int>
/// ```
///
/// ### How it works
/// - **Zero‑copy sharing**: The unmodifiable view uses the **same physical
///   storage** and **same lock** as the mutable source. No data is duplicated.
/// - **Mutation barrier**: The `modifiable` getter returns an empty set, and
///   the internal `TestTissue` policy is set to `readOnly`. Any attempt to
///   call `add`, `addFirst`, `removeLast`, `clear`, or `apply` with a mutation
///   function throws an [UnsupportedError] or is silently rejected.
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
/// final source = TissueQueue<String>(['A', 'B']);
/// final readOnly = source.unmodifiable;
/// // Render in a widget
/// myListView(data: readOnly.toList());
/// // Later, source.add('C');
/// // The widget automatically re‑renders because readOnly is live.
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements contained in the queue.
///
/// See also:
/// - [TissueQueue] – the mutable counterpart.
/// - [UnmodifiableTissue] – the general contract for read‑only tissues.
abstract interface class UnmodifiableTissueQueue<E> implements TissueQueue<E>, UnmodifiableTissue<E> {

  /// The primary architectural factory for instantiating an [UnmodifiableTissueQueue],
  /// materializing a read‑only, reactive double‑ended buffer from a set of
  /// initial [elements].
  ///
  /// This factory is a fundamental component of the framework's **Security Scoping**
  /// and **Deep Immutability** architecture. It is designed to initialise a queue
  /// node that conceptually represents a "Fixed Data Set" which can be observed
  /// and synchronised across the reactive graph, but strictly prohibits
  /// structural modification.
  ///
  /// ### When to use
  /// Use this when you need a standalone immutable queue that is not derived
  /// from a mutable source – e.g., for configuration data or constants.
  ///
  /// ### How it works
  /// - The factory creates a new queue node with a read‑only nucleus.
  /// - The provided [elements] are stored in a physical container that is
  ///   never modified.
  /// - If [unmodifiableElement] is `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - The queue is fully reactive but blocks all mutations.
  ///
  /// ### Parameters:
  /// - [elements]: The immutable data set.
  /// - [nucleus]: Optional blueprint; if omitted, a standard read‑only nucleus
  ///   is used.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A new [UnmodifiableTissueQueue<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final fixed = UnmodifiableTissueQueue<String>(
  ///   ['A', 'B', 'C'],
  ///   unmodifiableElement: true,
  /// );
  /// ```
  factory UnmodifiableTissueQueue(Iterable<E> elements, {
    TissueQueueNucleus<E>? nucleus,
    bool unmodifiableElement,
  }) = _UnmodifiableTissueQueue<E,TissueQueue<E>>;

  /// A high‑fidelity architectural factory for creating a **Deeply Immodifiable
  /// Reactive View** (Deputy) of an existing [TissueQueue].
  ///
  /// This constructor is the low‑level version of the `.unmodifiable` getter.
  /// You almost never call it directly – use `queue.unmodifiable` instead.
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
  /// - [bind]: The source queue to mirror.
  /// - [context]: Optional override for the execution context.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A read‑only [UnmodifiableTissueQueue<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueQueue<int>();
  /// final readOnly = UnmodifiableTissueQueue.view(source);
  /// ```
  factory UnmodifiableTissueQueue.view(TissueQueue<E> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissueQueue<E,TissueQueue<E>>.view;

  /// A low‑level architectural factory for materializing an
  /// [UnmodifiableTissueQueue] directly from a pre‑constructed
  /// reactive blueprint ([nucleus]).
  ///
  /// This constructor is the primary **Materialization Hook** used when the
  /// behavioural identity—including security rules, execution context, and
  /// synchronisation domain—has already been synthesised (e.g., via
  /// [TissueQueueNucleus.evolve] or a custom [Deputy] derivation).
  ///
  /// ### When to use
  /// Use this when you already have a pre‑configured read‑only nucleus and want
  /// to instantiate a queue from it. Typically used in advanced customisation
  /// or serialisation scenarios.
  ///
  /// ### How it works
  /// - The queue adopts the nucleus's rules, context, and receptor.
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
  /// A concrete [UnmodifiableTissueQueue<E>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlyNucleus = TissueQueueNucleus.evolve(
  ///   principal: myNucleus,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyQueue = UnmodifiableTissueQueue.fromNucleus(readOnlyNucleus);
  /// ```
  factory UnmodifiableTissueQueue.fromNucleus(TissueQueueNucleus<E> nucleus, {bool unmodifiableElement, Iterable<E>? elements})
  = _UnmodifiableTissueQueue<E,TissueQueue<E>>.fromNucleus;

  /// An advanced architectural factory for creating a specialised, type‑safe
  /// [UnmodifiableTissueQueue] with granular control over its behavioural
  /// and structural identity.
  ///
  /// This static method serves as the primary entry point for constructing
  /// read‑only reactive queues that require deep customisation of their
  /// reactive blueprint. It streamlines the process by simultaneously
  /// resolving the property hierarchy and initialising the node within the
  /// reactive data‑flow graph.
  ///
  /// ### When to use
  /// Use this when the simpler factories don't provide enough control – e.g.,
  /// when you need to specify a custom [capacity], [container], provide a
  /// specialised [receptor], or inherit from a [principal] nucleus.
  ///
  /// ### How it works
  /// - It builds a nucleus using [TissueQueueNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the unmodifiable queue from that nucleus, optionally
  ///   ingesting [elements].
  /// - The [unmodifiableElement] flag applies deep immutability.
  ///
  /// ### Parameters
  /// - [capacity]: Optional maximum size.
  /// - [elements]: Optional initial data.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - [bind]: Optional upstream cell.
  /// - [context]: Optional execution context.
  /// - [receptor]: Optional mutation processor.
  /// - [testRule]: Optional validation rule.
  /// - [synapses]: Optional propagation configuration.
  /// - [container]: Optional storage strategy (defaults to [Container.queue]).
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns
  /// A concrete [UnmodifiableTissueQueueBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlyQueue = UnmodifiableTissueQueue.create<int, TissueQueue<int>>(
  ///   capacity: 5,
  ///   elements: [1, 2, 3],
  ///   unmodifiableElement: true,
  /// );
  /// ```
  static UnmodifiableTissueQueueBase<E,C> create<E,C extends TissueQueue<E>>({
    int? capacity,
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
    TissueQueueNucleusBase<E,C>? principal,
  }) {
    return _UnmodifiableTissueQueue<E,C>.fromNucleus(
        TissueQueueNucleus.create<E,C>(
            capacity: capacity,

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