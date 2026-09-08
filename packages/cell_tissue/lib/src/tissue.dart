// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

// ignore_for_file: unused_element
// ignore_for_file: unused_field

/// A reactive collection that behaves like a normal Dart [Iterable] but is
/// fully governed, observable, and thread‑safe – the foundation of all
/// reactive containers in `cell_tissue`.
///
/// ### Where to start
/// You never implement this interface directly. Instead, use one of the
/// concrete subtypes that match your data structure needs:
/// - [TissueList] – an ordered, indexable list.
/// - [TissueSet] – a unique‑element set.
/// - [TissueMap] – a key‑value store.
/// - [TissueQueue] – a double‑ended FIFO/LIFO buffer.
/// - [TissueValue] – a single, reactive scalar value.
///
/// Each subtype provides the full Dart collection API you already know and
/// love (`add`, `remove`, `for‑in`, `map`, `where`, `fold`, etc.), but every
/// mutation is automatically validated, emits a reactive event, and is
/// synchronised through a thread‑safe lock.
///
/// ### When to use
/// Choose a `Tissue` collection whenever you need:
/// - **Observability**: UI components or other cells that react to changes
///   in the collection.
/// - **Validation**: Business rules enforced on every mutation (e.g., positive
///   numbers, non‑empty strings, max size).
/// - **Security**: Sharing a collection with read‑only views
///   ([unmodifiable]) or restricted proxies ([deputy]) without copying data.
/// - **Concurrency**: Thread‑safe updates from multiple isolates or event
///   handlers.
/// - **Auditability**: A complete causal trace of every change, with
///   provenance metadata.
///
/// ### How it works
/// Every `Tissue` is a [Cell] that holds two internal parts:
/// - A **[Container]** – the physical storage (e.g., a `List`, `Set`, `Map`).
/// - A **[TissueNucleus]** – an immutable blueprint that defines the
///   collection's validation rules, transformation logic, and propagation
///   behaviour.
///
/// When you mutate a tissue (e.g., `list.add(42)`), the operation:
/// 1. Passes through the [TestTissue] validation gate.
/// 2. Is applied atomically to the physical storage under a [Lock].
/// 3. Emits a [TissueEvent] (e.g., `ElementAddedEvent`).
/// 4. Propagates the event through the collection's [Synapses] to all
///    downstream observers.
///
/// This is the same reactive pipeline you know from [Cell], extended to
/// collections.
///
/// ### Non‑obvious
/// - **Initial population is silent**: When you create a tissue with initial
///   elements (e.g., `TissueList([1, 2, 3])`), **no** [TissueEvent] is emitted.
///   Observers only see events for mutations that happen *after* creation.
/// - **Deputies are zero‑copy**: Calling `.deputy()` or `.unmodifiable` on a
///   tissue creates a new view that shares the **same** physical storage.
///   No data is duplicated – changes to the source are immediately visible.
/// - **Unmodifiable is live**: The view returned by `.unmodifiable` is **not
///   a snapshot**. It stays in sync with the source indefinitely.
/// - **Deep immutability**: If `unmodifiableElement` is `true` (the default
///   in factories), any child [Cell] elements are automatically projected as
///   their `.unmodifiable` deputies – no "side‑door" mutations.
/// - **Validation per element**: When you add multiple elements via
///   `addAll`, each element is validated individually. Invalid ones are
///   silently skipped – they do **not** fail the entire operation.
/// - **Bounded queues**: For [TissueQueue], setting a `capacity` creates a
///   circular buffer. When the queue is full, adding a new element drops the
///   oldest one silently.
/// - **Equality**: `Tissue` instances compare like normal Dart collections.
///   `list1 == list2` compares the content. Deputies and their principals
///   are considered equal.
/// - **Async operations**: The `.async` getter provides a `Future`‑based API
///   for non‑blocking mutations, ideal for network callbacks or background
///   tasks.
///
/// ### Example: A validated task list
/// ```dart
/// final tasks = TissueList<Task>(
///   testRule: TestTissue<Task, TissueList<Task>>(
///     (task, {host, action, user}) => task.title.isNotEmpty,
///   ),
/// );
///
/// // Observe additions
/// tasks.listen((event) {
///   if (event is ElementAddedEvent<Task>) {
///     print('Added: ${event.payload.title}');
///   }
/// });
///
/// tasks.add(Task('Buy milk')); // passes validation → event fires
/// tasks.add(Task(''));          // rejected by validation → no event
/// ```
///
/// ### Example: A read‑only view for UI
/// ```dart
/// final source = TissueList<String>(['A', 'B', 'C']);
/// final readOnly = source.unmodifiable;
///
/// // Pass readOnly to a widget – it's safe to read, but cannot be mutated.
/// source.add('D');
/// print(readOnly.length); // 4 – the view is live!
/// ```
///
/// ### See also:
/// - [TissueList], [TissueSet], [TissueMap], [TissueQueue], [TissueValue]
///   for the concrete collection types.
/// - [TestTissue] for custom validation rules.
/// - [TissueReceptor] for custom mutation processing.
/// - [TissueEvent] for the change events emitted by tissues.
///
/// ### Type Parameters:
/// * [E] – The type of elements held within the collection.
abstract interface class Tissue<E> implements Cell, Iterable<E> {

  @override
  Iterable<E> followedBy(covariant Iterable<E> other);

  @override
  E reduce(covariant E Function(E value, E element) combine);

  @override
  E firstWhere(covariant bool Function(E element) test, {covariant E Function()? orElse});

  @override
  E lastWhere(covariant bool Function(E element) test, {covariant E Function()? orElse});

  /// The internal configuration and state storage for this tissue.
  ///
  /// This includes the [Container] (the underlying storage structure),
  /// [Synapses] (the reactive links), and the [TestTissue] (validation logic).
  TissueNucleus<E> get _nucleus;

  /// The primary factory for creating a [Tissue] collection.
  ///
  /// ### When to use
  /// Use this when you need a basic reactive collection with default behaviour.
  /// For more control (e.g., custom storage, context, or governance), use
  /// [Tissue.governed] or [Tissue.create].
  ///
  /// ### How it works
  /// - You provide an initial set of [elements].
  /// - Optionally, you can supply a [bind] (upstream cell), [receptor]
  ///   (transformation logic), [testRule] (validation), and [synapses]
  ///   (propagation configuration).
  /// - The tissue is created and automatically linked to any child cells.
  ///
  /// ### Parameters
  /// - [elements]: The initial data to populate the collection.
  /// - [bind]: Optional upstream [Cell] for reactive dependency.
  /// - [receptor]: [TissueReceptor] for processing mutations.
  /// - [testRule]: [TestTissue] for validating changes.
  /// - [synapses]: [Synapses] configuration for broadcasting.
  ///
  /// ### Returns
  /// A concrete [Tissue] subtype.
  ///
  /// ### Example
  /// ```dart
  /// final list = Tissue<int>([1, 2, 3]);
  /// print(list.length); // 3
  /// ```
  factory Tissue(
      Iterable<E> elements, {
        Cell? bind,
        TissueReceptor<E, Tissue<E>> receptor,
        TestTissue<E, Tissue<E>> testRule,
        Synapses synapses,
      }) = _Tissue<E,Iterable<E>,Tissue<E>>;

  /// Creates a [Tissue] with explicit governance and lifecycle policies.
  ///
  /// ### When to use
  /// Use this when you need fine‑grained control over the collection's
  /// authority, lifecycle, and security – e.g., for system‑critical data.
  ///
  /// ### How it works
  /// - Accepts all the standard parameters plus [context] (authority tier) and
  ///   [ephemeralPolicy] (TTL/event‑based reclamation).
  /// - The [context] determines the execution priority and security tier.
  /// - The [ephemeralPolicy] allows automatic cleanup of stale collections.
  ///
  /// ### Parameters
  /// - [elements]: Initial data.
  /// - [ephemeralPolicy]: Optional TTL or event‑limit policy.
  /// - [bind]: Optional upstream [Cell].
  /// - [context]: [Context] defining authority and priority.
  /// - [receptor]: [TissueReceptor] for mutation processing.
  /// - [testRule]: [TestTissue] for validation.
  /// - [synapses]: [Synapses] configuration.
  ///
  /// ### Example
  /// ```dart
  /// final secureList = Tissue.governed<int>(
  ///   [1, 2, 3],
  ///   context: Context.secureEnclave(partOf: 'CryptoModule'),
  ///   testRule: TestTissue<int>((v) => v >= 0),
  /// );
  /// ```
  factory Tissue.governed(
      Iterable<E> elements, {
        EphemeralPolicy? ephemeralPolicy,

        Cell? bind,
        Context context,
        TissueReceptor<E, Tissue<E>> receptor,
        TestTissue<E, Tissue<E>> testRule,
        Synapses synapses,
      }) = _Tissue<E,Iterable<E>,Tissue<E>>;


  /// Creates an empty [Tissue] container, initializing a reactive node
  /// with no initial members but a fully established behavioral blueprint.
  ///
  /// The [empty] factory is a specialized architectural constructor designed
  /// for **Lazy Initialization** and **Late-Binding** scenarios within the
  /// `cell_tissue` ecosystem. It facilitates the creation of a "Placeholder"
  /// reactive node—a container that possesses identity, governance (rules),
  /// and synchronization, but currently holds no physical state.
  ///
  /// ### When to use
  /// Use [empty] when you need a tissue node that exists in the reactive graph
  /// but will be populated later – e.g., for a collection that is bound to a
  /// `Future` result or a placeholder for data that loads asynchronously.
  ///
  /// ### How it works
  /// - A tissue node is created with the specified [context], [receptor],
  ///   [testRule], and [synapses].
  /// - No elements are stored – the container is empty.
  /// - The node is fully reactive and can be observed or linked to.
  /// - The node can be populated later via `add`, `addAll`, or `setAll`.
  ///
  /// ### Parameters:
  /// - [bind]: Optional. A [Cell] to which this tissue's lifecycle or
  ///   upstream synchronization is tethered.
  /// - [context]: The operational environment (defaults to [Context.system]).
  ///   Determines priority and security authority for future signals.
  /// - [receptor]: A [TissueReceptor] defining how the collection
  ///   will handle future mutation signals (defaults to [passThrough]).
  /// - [testRule]: A [TestTissue] validator acting as the gatekeeper
  ///   for all future membership changes (defaults to [allowAll]).
  /// - [synapses]: Configuration for pulse propagation and child-linking.
  ///
  /// ### Returns:
  /// A concrete, empty [Tissue<E>] implementation prepared for
  /// participation in the reactive graph.
  factory Tissue.empty({
    Cell? bind,
    Context context = Context.system,
    TissueReceptor<E, Tissue<E>> receptor = TissueReceptor.passThrough,
    TestTissue<E, Tissue<E>> testRule = TestTissue.allowAll,
    Synapses synapses = Synapses.enabled,
  }) {
    if (bind == null && testRule == TestTissue.allowAll && synapses == Synapses.disabled && context == Context.system) {
      return const TissueNever();
    }
    return _Tissue<E, Iterable<E>,Tissue<E>>.empty(
        bind: bind,
        context: context,
        receptor: receptor,
        testRule: testRule
    );
  }

  /// Creates a [Tissue] from a pre‑configured [TissueNucleus] blueprint.
  ///
  /// ### When to use
  /// Use this when you have a reusable nucleus configuration that you want to
  /// instantiate with different data – e.g., a "ValidatedUserList" blueprint.
  ///
  /// ### How it works
  /// - The nucleus provides the rules, context, and receptor.
  /// - The optional [elements] provide the initial data.
  /// - This is the primary way to instantiate **deputies** – restricted views
  ///   that share the same nucleus but apply different rules.
  ///
  /// ### Parameters
  /// - [nucleus]: The pre‑configured [TissueNucleus] blueprint.
  /// - [elements]: Optional initial data to populate the collection.
  ///
  /// ### Returns
  /// A [Tissue] instance governed by the provided nucleus.
  ///
  /// ### Example
  /// ```dart
  /// final nucleus = TissueNucleus.create<int>(
  ///   testRule: TestTissue<int>((v) => v >= 0),
  /// );
  /// final list = Tissue.fromNucleus(nucleus, elements: [1, 2, 3]);
  /// ```
  factory Tissue.fromNucleus(TissueNucleus<E> nucleus, {Iterable<E>? elements,})
  = _Tissue<E,Iterable<E>,Tissue<E>>.fromNucleus;

  /// Creates a read‑only, reactive projection (Deputy) of an existing [Tissue].
  ///
  /// ### When to use
  /// Use this when you need to share a collection with a component that should
  /// **observe** changes but **never** initiate them – e.g., passing a list to
  /// a UI widget that should only render data.
  ///
  /// ### How it works
  /// - Shares the same physical storage and lock as the [bind] source.
  /// - Applies a `TestTissue.readOnly` policy – any mutation attempt is blocked.
  /// - If `unmodifiableElement` is `true`, any child [Cell] elements are also
  ///   projected as read‑only deputies.
  /// - The view remains **live** – changes to the source are immediately
  ///   reflected.
  ///
  /// ### Parameters
  /// - [bind]: The source [Tissue] to mirror.
  /// - [context]: Optional override for execution context.
  /// - [unmodifiableElement]: If `true`, recursively projects child cells as
  ///   unmodifiable.
  ///
  /// ### Returns
  /// A read‑only [Tissue] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueList<int>([1, 2, 3]);
  /// final readOnly = Tissue.unmodifiable(source);
  /// // readOnly.add(4); // Throws UnsupportedError
  /// source.add(4);
  /// print(readOnly.length); // 4 (automatically updated)
  /// ```
  factory Tissue.unmodifiable(Tissue<E> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissue<E, Tissue<E>>.view;

  /// A low‑level factory for creating a [Tissue] with explicit control over
  /// its internal implementation types and storage.
  ///
  /// ### When to use
  /// Only if you are building a **custom collection type** that needs precise
  /// control over the storage strategy and implementation types. For standard
  /// use, prefer [Tissue] or one of the concrete subtypes.
  ///
  /// ### How it works
  /// - Allows you to specify the physical storage [container] (List, Set, Map,
  ///   Queue, etc.).
  /// - Supports the **Deputy Pattern** via the [principal] parameter – you can
  ///   inherit configuration from an existing nucleus.
  /// - The [forceLock] flag controls whether the collection has its own
  ///   synchronisation primitive or shares one with a principal.
  ///
  /// ### Type Parameters
  /// - [E]: The element type.
  /// - [I]: The internal storage type (e.g., `List<E>`, `Set<E>`).
  /// - [C]: The concrete tissue interface.
  ///
  /// ### Parameters
  /// - [elements]: Initial data.
  /// - [bind]: Optional upstream [Cell].
  /// - [context]: [Context] for authority and priority.
  /// - [receptor]: [TissueReceptor] for mutation processing.
  /// - [testRule]: [TestTissue] for validation.
  /// - [synapses]: [Synapses] configuration.
  /// - [container]: Physical storage strategy.
  /// - [user]: Optional custom metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Ancestor nucleus to inherit configuration from.
  ///
  /// ### Returns
  /// A [TissueBase] configured with the specified blueprint.
  ///
  /// ### Example
  /// ```dart
  /// final custom = Tissue.create<int, List<int>, TissueList<int>>(
  ///   container: Container.growableFalse,
  ///   elements: [1, 2, 3],
  /// );
  /// ```
  static TissueBase<E,I,C> create<E, I extends Iterable<E>, C extends Tissue<E>>({
    Iterable<E>? elements,

    Cell? bind,
    Context? context = Context.system,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueNucleusBase<E,I,C>? principal
  }) {
    final nucleus = TissueNucleus.create<E,I,C>(
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
    return _Tissue<E,I,C>.fromNucleus(nucleus, elements: elements);

  }

  /// Synthesizes a specialised **Mandate Handle** (Deputy) of this collection,
  /// providing a scoped, authoritative interface to the underlying state.
  ///
  /// ### When to use
  /// Use this when you need a restricted view of a collection – e.g., read‑only,
  /// scoped authority, temporary access, or sandboxed simulation.
  ///
  /// ### How it works
  /// - You provide a new [context] (authority, clearance, lease) and/or an
  ///   additional [testRule] (validation gate). The deputy shares the principal's
  ///   state and lock but applies the new rules.
  /// - If all parameters are left at their defaults, the method returns `this`
  ///   – no proxy is created.
  ///
  /// ### Non‑obvious
  /// - The deputy's [testRule] is layered **on top** of the principal's rule.
  ///   You can only narrow permissions, never expand them.
  /// - Deputies are logically equal to their principal: `deputy == principal`
  ///   is `true`, so they work seamlessly in [Set]s and [Map]s.
  /// - The deputy gets its own independent [Synapses] registry by default,
  ///   so it can have its own observers separate from the principal.
  ///
  /// ### Parameters
  /// - [context]: [DeputyContext] defining the authority tier.
  /// - [testRule]: Additional [TestTissue] validation, layered on top.
  /// - [ephemeralPolicy]: Optional TTL/event‑count lifecycle for this handle.
  /// - [synapses]: The deputy's own observer registry.
  ///
  /// ### Returns
  /// A new [Tissue] instance acting as a governed proxy of the principal.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueList<String>(['A', 'B', 'C']);
  /// final readOnly = await source.deputy(testRule: TestTissue.readOnly);
  /// // readOnly.add('D'); // blocked
  /// source.add('D'); // readOnly reflects the change
  /// ```
  @override
  FutureOr<Tissue<E>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) => deputy(context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);

  /// Returns a read‑only, reactive projection (Deputy) of this [Tissue].
  ///
  /// ### When to use
  /// Use this when you need to share the collection with components that
  /// should **observe** but **never** mutate it – e.g., UI widgets, loggers.
  ///
  /// ### How it works
  /// - Shares the same physical storage and lock as the source.
  /// - Applies `TestTissue.readOnly` – all mutations are blocked.
  /// - The view remains **live** – changes to the source are immediately
  ///   reflected.
  /// - If the source contains child [Cell]s, they are also projected as
  ///   read‑only deputies.
  ///
  /// ### Returns
  /// A read‑only [Tissue] instance.
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
  Tissue<E> get unmodifiable;

  /// The [TestTissue] validation logic currently governing this collection.
  ///
  /// ### When to use
  /// Use this for conditional UI logic (e.g., disabling an "Add" button) or for
  /// debugging to understand why a mutation was rejected.
  ///
  /// ### How it works
  /// - Delegates to the nucleus's `testRule`.
  /// - For deputies, this returns the **composed** rule – the principal's rule
  ///   plus the deputy's additional rule.
  ///
  /// ### Returns
  /// The [TestTissue] instance responsible for authorising mutations.
  @override
  TestTissue get validate;

  /// The [Context] defining the authority tier, priority, and security domain
  /// of this collection.
  ///
  /// ### When to use
  /// Read this when you need to know the operational context – e.g., for
  /// conditional logic based on the authority tier.
  ///
  /// ### How it works
  /// - Delegates to the nucleus's `context`.
  /// - For deputies, this may be overridden to a different authority tier.
  @override
  Context get context;

  /// Indicates whether this tissue is a terminal node – i.e., it has no
  /// downstream observers and does not broadcast pulses.
  ///
  /// ### When to use
  /// Mostly informational – used internally to optimise propagation.
  @override
  bool get isTerminal;

  /// Indicates whether this tissue has been invalidated by its
  /// [EphemeralPolicy] (e.g., TTL expired).
  ///
  /// ### When to use
  /// Check this before interacting with a tissue to avoid acting on a dead node.
  @override
  bool get isInvalidated;

  /// Indicates whether this tissue is governed (has a non‑default context,
  /// testRule, or receptor).
  ///
  /// ### When to use
  /// This is informational – you might use it to conditionally apply stricter
  /// checks in custom logic.
  @override
  bool get isGoverned;

  /// Executes a whitelisted function on this tissue via the command gateway.
  ///
  /// ### When to use
  /// This is a low‑level method; you rarely call it directly. Instead, use the
  /// higher‑level methods like `add`, `remove`, etc.
  ///
  /// ### How it works
  /// - Only functions listed in `modifiable` can be executed.
  /// - The call is gated by `testRule.action` – if rejected, `null` is returned.
  ///
  /// ### Returns
  /// The result of the function execution, or `null` if rejected.
  @override
  dynamic apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
  });

  /// The exhaustive whitelist of functions that can be invoked via `apply`.
  ///
  /// ### When to use
  /// Rarely – this is used internally for the command pattern and by deputies
  /// to restrict operations.
  @override
  Iterable<Function> get modifiable;

  /// Provides a high‑level, asynchronous interface for interacting with this
  /// collection.
  ///
  /// ### When to use
  /// Use this when you need to perform operations asynchronously – e.g., from
  /// UI event handlers or background tasks.
  ///
  /// ### How it works
  /// - All operations are scheduled through the cell's lock.
  /// - The result is wrapped in a [Future].
  ///
  /// ### Example
  /// ```dart
  /// final cell = TissueList<int>([1, 2, 3]);
  /// await cell.async.add(4);
  /// ```
  @override
  ModifiableAsync<Cell> get async;

}

/// A read‑only, reactive projection of a [Tissue] – a "security shadow"
/// that shares physical storage but prohibits all mutations.
///
/// [UnmodifiableTissue] is the interface you get when you call `.unmodifiable`
/// on any collection (list, set, map, queue, or value). It is a live,
/// synchronised view that reflects changes made to the mutable source,
/// but blocks any attempt to change the data through this handle.
///
/// ### When to use
/// Use an unmodifiable tissue when you need to share a collection with a
/// component that should **observe** changes but **never** initiate them.
/// Common scenarios include:
/// - Passing a list to a UI widget that only renders data.
/// - Exposing internal state to a logger or analytics module.
/// - Providing a safe view to a plugin or sandboxed code.
/// - Implementing a "read‑only" API for external consumers.
///
/// You obtain an instance by calling the `.unmodifiable` getter on any [Tissue]:
/// ```dart
/// final source = TissueList<int>([1, 2, 3]);
/// final readOnly = source.unmodifiable; // UnmodifiableTissue<int>
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
///   mutations – you cannot get a mutable reference to a child cell through
///   a read‑only collection.
///
/// ### Non‑obvious
/// - **It is not a snapshot**: Unlike `List.unmodifiable` in Dart, this view
///   is **live**. If the source changes, the view changes with it. This is
///   essential for reactive UIs that need to stay in sync.
/// - **Equality**: An unmodifiable view is logically equal to its source.
///   `source == source.unmodifiable` is `true` (in terms of `==`), and they
///   share the same `hashCode`. This means they can be used interchangeably
///   in [Set]s and [Map]s.
/// - **Recursive projection**: If you iterate over an unmodifiable view and
///   the elements are themselves [Cell]s, you receive **unmodifiable deputies**
///   of those cells. This ensures that deep immutability is enforced.
/// - **Own observer registry**: The unmodifiable view has its own
///   [Synapses] registry. Observers attached to the view are notified of
///   changes, but they are separate from observers attached to the source.
/// - **Terminal behaviour**: An unmodifiable view is not necessarily
///   terminal. It can still have downstream observers, and it participates
///   in propagation waves just like any other cell.
///
/// ### Example: Read‑only UI projection
/// ```dart
/// final source = TissueList<String>(['Apple', 'Banana']);
/// final readOnly = source.unmodifiable;
///
/// // Render in a widget
/// myListView(data: readOnly);
///
/// // Later, source changes
/// source.add('Cherry');
/// // The widget automatically re‑renders because readOnly is live.
/// ```
///
/// ### Example: Deep immutability in action
/// ```dart
/// final source = TissueList<Task>([Task('Buy milk')]);
/// final readOnly = source.unmodifiable;
///
/// // Access the task – it's automatically unmodifiable
/// final task = readOnly.first; // returns UnmodifiableTask
/// // task.complete(); // blocked – task is read‑only
///
/// // The source can still change the task
/// source.first.complete();
/// // readOnly.first.isComplete now reflects the change
/// ```
///
/// See also:
/// - [Tissue.unmodifiable] – the getter that returns this interface.
/// - [UnmodifiableTissueList], [UnmodifiableTissueSet], [UnmodifiableTissueMap],
///   [UnmodifiableTissueQueue], [UnmodifiableTissueValue] – concrete
///   implementations for each collection type.
/// - [Unmodifiable] – the marker interface for all read‑only proxies.
abstract interface class UnmodifiableTissue<E> implements Tissue<E>, Unmodifiable {

  /// Creates a permanently read‑only reactive collection from a fixed set of elements.
  ///
  /// ### When to use
  /// - You have a fixed set of data that must never change (e.g., a list of
  ///   country codes, a set of permissions, a map of configuration values).
  /// - You need the collection to be observable (listeners can react to changes,
  ///   though there won't be any) and to participate in the reactive graph.
  /// - You want to enforce immutability at the type level – the collection will
  ///   reject any mutation attempt.
  ///
  /// You rarely call this factory directly. In most cases, you get an unmodifiable
  /// tissue by calling `.unmodifiable` on an existing mutable tissue:
  /// ```dart
  /// final readOnly = myList.unmodifiable;
  /// ```
  /// Use this factory only when you need to create a standalone immutable collection
  /// that is not derived from a mutable source – e.g., for configuration data that
  /// should never change.
  ///
  /// ### How it works
  /// - The factory creates a new tissue node with a **read‑only nucleus**.
  /// - The provided [elements] are stored in a physical container that is never
  ///   modified. The storage is allocated atomically under a lock, so observers
  ///   never see a partially populated state.
  /// - If [unmodifiableElement] is `true` (the default), any element that is itself
  ///   a [Cell] is automatically wrapped in its `.unmodifiable` deputy when accessed.
  ///   This prevents "side‑door" mutations through nested mutable cells.
  /// - The tissue is fully reactive: it can be observed, it participates in the
  ///   graph, and it can be used as a source for derived tissues. It simply
  ///   blocks all mutations.
  ///
  /// ### Non‑obvious
  /// - The collection is **not a snapshot** – it is a live, reactive node.
  ///   However, because the data is fixed, it will never emit change pulses.
  /// - The provided [nucleus] parameter allows you to customise the context,
  ///   synapses, and other governance aspects even for an immutable collection.
  ///   If omitted, a default read‑only nucleus is used.
  /// - The [unmodifiableElement] flag only affects the behaviour when you access
  ///   elements *through this collection*. If you hold a direct reference to a
  ///   mutable child cell, it remains mutable – the collection only projects
  ///   it as unmodifiable when you retrieve it via its API.
  ///
  /// ### Example: Static configuration
  /// ```dart
  /// final countries = UnmodifiableTissue<String>(
  ///   ['US', 'GB', 'DE'],
  ///   unmodifiableElement: true,
  /// );
  /// // countries.add('FR'); // throws UnsupportedError
  /// print(countries.length); // 3
  /// ```
  ///
  /// ### Parameters:
  /// - [elements]: The immutable data set to populate the collection.
  /// - [nucleus]: Optional blueprint to customise the governance context.
  ///   If omitted, a standard read‑only nucleus is used.
  /// - [unmodifiableElement]: If `true` (default), any child [Cell] elements
  ///   are projected as unmodifiable deputies. Prevents nested mutations.
  ///
  /// ### Returns:
  /// A new [UnmodifiableTissue<E>] instance that is live, observable, but
  /// strictly immutable.
  factory UnmodifiableTissue(Iterable<E> elements, {
    TissueNucleus<E>? nucleus,
    bool unmodifiableElement,
  }) = _UnmodifiableTissue<E,Tissue<E>>;

  /// Creates a live, read‑only "view" (deputy) of an existing mutable tissue.
  ///
  /// ### When to use
  /// - You have a mutable tissue that you want to share with code that should
  ///   only read data, never write it.
  /// - You need the view to operate under a different execution context
  ///   (e.g., a lower priority tier) than the source.
  /// - You want to enforce deep immutability: any child cells retrieved through
  ///   this view should also be read‑only.
  ///
  /// This factory is the low‑level constructor for the `.unmodifiable` getter.
  /// You almost never call it directly – instead, just write:
  /// ```dart
  /// final readOnly = myList.unmodifiable;
  /// ```
  /// Use this factory only when you need fine‑grained control over the view's
  /// [context] or the [unmodifiableElement] flag.
  ///
  /// ### How it works
  /// - The factory creates a new tissue node that shares the **same physical
  ///   storage** and **same lock** as the [bind] source. No data is copied.
  /// - It applies a `TestTissue.readOnly` gatekeeper, so any mutation attempt
  ///   through this view is rejected.
  /// - The view is **live**: if the source changes, the view reflects the change
  ///   immediately and atomically.
  /// - If [unmodifiableElement] is `true` (the default), any element retrieved
  ///   that is itself a [Cell] is automatically returned as its `.unmodifiable`
  ///   deputy. This prevents a consumer from obtaining a mutable handle to a
  ///   nested cell through the view.
  /// - The view has its own [Synapses] registry, so observers attached to the
  ///   view receive pulses independently of observers attached to the source.
  ///
  /// ### Non‑obvious
  /// - The view is **not a snapshot** – it stays in sync with the source.
  /// - Equality (`==`) between the view and the source returns `true` – they
  ///   are considered the same logical entity.
  /// - If you override the [context], the view runs with that authority tier,
  ///   which affects scheduling and security checks for any observers attached
  ///   to the view.
  ///
  /// ### Example: UI‑safe projection
  /// ```dart
  /// final source = TissueList<String>(['A', 'B']);
  /// final uiView = UnmodifiableTissue.view(
  ///   source,
  ///   context: Context.module('UI'),
  ///   unmodifiableElement: true,
  /// );
  /// // uiView is safe to pass to a widget tree
  /// ```
  ///
  /// ### Parameters:
  /// - [bind]: The mutable source tissue to mirror.
  /// - [context]: Optional override for the execution context of the view.
  ///   If omitted, it inherits the source's context.
  /// - [unmodifiableElement]: If `true` (default), child cells are projected
  ///   as unmodifiable. Prevents nested mutations.
  ///
  /// ### Returns:
  /// A read‑only deputy that stays live‑synced with the source.
  factory UnmodifiableTissue.view(Tissue<E> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissue<E,Tissue<E>>.view;

  /// Instantiates an unmodifiable tissue from a pre‑built reactive blueprint.
  ///
  /// ### When to use
  /// - You have a reusable nucleus configuration (e.g., from a cache or a
  ///   factory) that already defines the governance, context, and synapses.
  /// - You are building a custom deputy implementation and need to instantiate
  ///   an unmodifiable view from a nucleus that may have been inherited or
  ///   transformed via `.evolve`.
  /// - You need to restore an unmodifiable collection from a serialised state
  ///   where the nucleus is already reconstructed.
  ///
  /// This is an advanced, low‑level factory. You typically use the simpler
  /// [UnmodifiableTissue] factory or the `.unmodifiable` getter instead.
  /// Use this only when you already have a custom [TissueNucleus] that you
  /// want to materialise as a read‑only collection.
  ///
  /// ### How it works
  /// - The factory takes a [TissueNucleus] that **must** be configured with a
  ///   read‑only test rule (or at least one that rejects mutations). If not,
  ///   the resulting tissue may still allow mutations – use with care.
  /// - The nucleus may be a root blueprint or a derived one (e.g., from
  ///   `TissueNucleus.evolve`). It defines the storage strategy, context,
  ///   synapses, and validation logic.
  /// - If [elements] are provided, they are ingested into the physical container
  ///   atomically during construction, ensuring a consistent initial state.
  /// - If [unmodifiableElement] is `true` (the default), child cells are
  ///   projected as unmodifiable when accessed.
  ///
  /// ### Non‑obvious
  /// - The nucleus is **not** automatically cloned; if it is already activated
  ///   (bound to another tissue), the factory will clone it internally to avoid
  ///   sharing locks and synapses. This is handled by the underlying
  ///   `Cell.fromNucleus` machinery.
  /// - The [unmodifiableElement] flag is applied *in addition* to whatever
  ///   projection rules the nucleus might have. It is a layer of safety.
  /// - The resulting tissue is live and can be observed; it just cannot be
  ///   mutated through this handle.
  ///
  /// ### Example: Reusing a validated blueprint
  /// ```dart
  /// final blueprint = TissueNucleus.create<int>(
  ///   testRule: TestTissue<int>((v) => v > 0),
  /// );
  /// final readOnly = UnmodifiableTissue.fromNucleus(
  ///   blueprint,
  ///   elements: [1, 2, 3],
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [nucleus]: The pre‑configured blueprint that governs the collection's
  ///   behaviour, storage, and context.
  /// - [unmodifiableElement]: If `true` (default), child cells are projected
  ///   as unmodifiable when accessed.
  /// - [elements]: Optional initial data to populate the collection atomically.
  ///
  /// ### Returns:
  /// An unmodifiable tissue instance governed by the provided nucleus.
  factory UnmodifiableTissue.fromNucleus(TissueNucleus<E> nucleus, {bool unmodifiableElement, Iterable<E>? elements})
  = _UnmodifiableTissue<E,Tissue<E>>.fromNucleus;

}