// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// Internal implementation of [TissueQueueNucleus] for reactive queues.
///
/// [_TissueQueueNucleus] is the concrete nucleus that powers `_TissueQueue`.
/// It extends [TissueQueueNucleusBase] and provides the specific logic for
/// cloning and evolution.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// factories on [TissueQueueNucleus] instead.
///
/// ### How it works
/// - It extends [TissueQueueNucleusBase] and provides the concrete implementation.
/// - The `clone` getter creates a fresh copy with its own lock and synapses.
/// - The `evolve` constructor creates a deputy nucleus with overridden properties.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue queue type.
class _TissueQueueNucleus<E,C extends TissueQueue<E>> extends TissueQueueNucleusBase<E,C> {

  _TissueQueueNucleus({
    super.capacity,

    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,

    super.forceLock,
    super.user,
  }) : super();

  _TissueQueueNucleus.evolve({
    int? capacity,

    Cell? bind,
    Context? context,
    TissueReceptor<E,C>? receptor,
    TestTissue<E,C>? testRule,
    Synapses? synapses,

    bool forceLock = true,

    TissueQueueNucleus<E>? override,
    required super.principal
  }) : super.evolve(
      override: override ?? _TissueQueueNucleus<E,C>.fromRecord(
          TissueNucleusBase.local<E,Queue<E>,C>(
              bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock,
              container: Container.queue,
              others: capacity != null ? (capacity: capacity) : null
          ))
  );

  _TissueQueueNucleus.fromRecord(super.record) : super.fromRecord();

  /// Creates an independent, decoupled clone of this nucleus.
  ///
  /// ### When to use
  /// This is used internally when creating a new queue from a template nucleus.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a queue instance.
  ///
  /// ### Returns:
  /// A new [TissueQueueNucleusBase] instance with identical behavioural logic.
  @override
  TissueQueueNucleusBase<E,C> get clone {
    return TissueQueueNucleus.create<E,C>(
      container: containerType,
      context: context,
      receptor: receptor,
      testRule: testRule,
      synapses: synapses != Synapses.disabled ? Synapses.enabled : Synapses.disabled,
      user: user,
      forceLock: false,
      capacity: capacity != -1 ? capacity : null,
    );
  }

}

/// The foundational blueprint that defines the behaviour, storage strategy,
/// and governance of a reactive [TissueQueue].
///
/// [TissueQueueNucleusBase] holds the immutable configuration – the receptor,
/// validation rule, context, synapses, and the queue's capacity – that governs
/// how a queue reacts to mutations. It is the **DNA** of every reactive queue.
///
/// ### When to use
/// Only if you are building a custom queue type that needs to override the
/// default nucleus behaviour. For standard use, the provided factories
/// are sufficient.
///
/// You never extend this class directly. The framework provides concrete
/// implementations via [TissueQueueNucleus.create] and the [TissueQueue] factories.
/// This class is the base that powers the internal `_TissueQueueNucleus`.
///
/// ### How it works
/// - It extends [TissueNucleusBase] to inherit the core property resolution
///   engine (bitmask records, principal chain, lock management).
/// - It specialises the storage type to [Queue<E>] and forces the container
///   strategy to [Container.queue] – a double‑ended buffer optimised for O(1)
///   operations at both ends.
/// - It stores the [capacity] (maximum size, or -1 for unbounded) in the
///   `others` segment of the record.
/// - It implements the [containerType] and [capacity] resolution by walking up
///   the `principal` chain, with sensible defaults.
/// - It provides the `clone` getter to create an independent copy of the
///   nucleus with a fresh lock and synapses, essential for creating new
///   queue instances from a template.
///
/// ### Non‑obvious
/// - The [capacity] is **structural** – it is fixed at creation and inherited
///   by all deputies. A deputy cannot change an unbounded queue into a bounded
///   one, or vice versa, unless it explicitly overrides the capacity at
///   creation time (which is possible via `TissueQueueNucleus.evolve` with a
///   new capacity).
/// - The nucleus is a **flyweight** – many queues can share the same nucleus
///   without duplicating memory.
/// - The [clone] getter creates a root nucleus (no principal) with its own
///   lock, making it safe to use for independent queue instances.
/// - The [principal] chain enables **prototype inheritance** – a deputy can
///   override only specific properties (like `testRule`) while inheriting the
///   rest from its principal.
/// - The [capacity] is used for **backpressure regulation** – when the queue
///   is full, `add` operations may drop the oldest element or reject the new
///   one, depending on the specific `TissueQueue` implementation.
///
/// ### Example: Reusing a validated queue nucleus
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
/// - [E]: The type of elements held within the associated [TissueQueue].
/// - [C]: The specific [TissueQueue] implementation type (usually `TissueQueue<E>`),
///   allowing for type‑safe pulse processing within the hierarchy.
///
/// See also:
/// - [TissueQueue] – the reactive queue instance governed by this nucleus.
/// - [TissueQueueNucleus] – the public interface for queue configurations.
/// - [TissueNucleusBase] – the base class for all collection nuclei.
abstract class TissueQueueNucleusBase<E,C extends TissueQueue<E>>
    extends TissueNucleusBase<E, Queue<E>, C>
    implements TissueQueueNucleus<E> {

  /// **Primary Constructor** – defines the immutable behaviour, capacity,
  /// and storage strategy for a reactive queue.
  ///
  /// ### When to use
  /// **Internal framework use only.** This constructor is `public` only so
  /// that concrete subclasses (like `_TissueQueueNucleus`) can invoke it via
  /// `super()`. **Application code should never call this directly.**
  ///
  /// If you need a nucleus, use [TissueQueueNucleus.create] to create one
  /// from scratch, or [TissueQueueNucleus.evolve] to derive one from an
  /// existing principal.
  ///
  /// You are writing a custom queue implementation that extends
  /// `TissueQueueNucleusBase` and need to pass configuration up to the base.
  ///
  /// ### How it works
  /// 1. The [capacity] parameter sets the maximum number of elements (use -1
  ///    for unbounded). It is stored in the `others` segment of the record.
  /// 2. The physical container is always [Container.queue], a high‑performance
  ///    double‑ended buffer.
  /// 3. All other parameters are passed to the super‑constructor, which
  ///    stores them in a memory‑optimised record using bitmasking.
  /// 4. The resulting nucleus is immutable – you cannot change its
  ///    configuration after creation.
  ///
  /// ### Non‑obvious
  /// - The [capacity] is **structural** – once set, it cannot be changed by a
  ///   deputy (unless explicitly overridden via `evolve`).
  /// - The [receptor] is automatically cloned if it is already activated
  ///   (bound to another cell), ensuring that each nucleus starts with a
  ///   clean logic instance.
  /// - If [synapses] is [Synapses.enabled], a fresh, empty registry is
  ///   created for the new queue. If you pass [Synapses.disabled], the queue
  ///   will be terminal (no broadcasts).
  /// - The [forceLock] flag controls whether a new synchronization lock is
  ///   allocated. `false` (default) creates a new lock; `true` shares the
  ///   principal's lock (used for deputies).
  ///
  /// ### Example (Internal – how the framework uses it)
  /// ```dart
  /// class _MyCustomQueueNucleus<E> extends TissueQueueNucleusBase<E, TissueQueue<E>> {
  ///   _MyCustomQueueNucleus({super.capacity = 10, ...}) : super();
  /// }
  /// ```
  ///
  /// ### Parameters:
  /// - [capacity]: Optional maximum number of elements (-1 for unbounded).
  /// - [bind]: Optional upstream [Cell] – the queue will automatically
  ///   mirror changes from this source (deputy pattern).
  /// - [context]: Security tier and execution domain (default: [Context.system]).
  /// - [receptor]: Mutation processor – defaults to [TissueReceptor.passThrough].
  /// - [testRule]: Validation gate – defaults to [TestTissue.allowAll].
  /// - [synapses]: Distribution configuration – defaults to [Synapses.enabled].
  /// - [forceLock]: If `true`, shares the principal's lock (optimisation
  ///   for deputies); if `false` (default), allocates a new lock.
  /// - [user]: Optional custom metadata (e.g., UI hints, serialisation tags).
  TissueQueueNucleusBase({
    int? capacity,

    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,

    super.forceLock,
    super.user,

  }) : super(container: Container.queue, others: capacity != null ? (capacity: capacity) : null);

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
  /// - The record must contain all necessary fields for a queue nucleus,
  ///   including the `container` (of type [Container<Queue<E>>]) and a
  ///   synchronisation [Lock] (unless sharing one via a principal).
  /// - The `capacity` must be present in the `others` segment if it differs
  ///   from -1.
  /// - If the record is malformed, the resulting nucleus may behave
  ///   unpredictably – use with extreme caution.
  /// - This constructor is `const`‑friendly, enabling compile‑time
  ///   instantiation of static nuclei for zero‑cost default configurations.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final record = (mask: (container: Container.queue, others: (capacity: 10)), principal: null);
  /// final nucleus = TissueQueueNucleusBase.fromRecord(record: record);
  /// ```
  ///
  /// ### Parameters:
  /// - [record]: The internal property record – an implementation‑specific
  ///   Dart `Record` containing all nucleus fields.
  const TissueQueueNucleusBase.fromRecord(super.record) : super.fromRecord();

  /// **Evolution Constructor** – creates a specialised deputy nucleus by
  /// extending an existing [principal].
  ///
  /// ### When to use
  /// This constructor is part of the **internal deputy machinery**. While it
  /// is `public`, it is intended to be called only by the framework when
  /// you invoke `deputy()` on a [TissueQueue]. **Application code should use
  /// `TissueQueue.deputy()` or [TissueQueueNucleus.evolve] instead.**
  ///
  /// You are building a custom deputy implementation and need to control
  /// exactly how a child nucleus inherits from its principal.
  ///
  /// ### How it works
  /// 1. The [principal] provides the baseline configuration (including the
  ///    container type and capacity).
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
  /// - The [capacity] is **inherited from the principal** unless explicitly
  ///   overridden via the [capacity] parameter in this call, or via the
  ///   [override] nucleus.
  /// - If you override the [synapses], the deputy gets its own observer
  ///   registry – observers attached to the deputy are separate from
  ///   those on the principal.
  /// - The [testRule] passed here is **layered on top** of the principal's
  ///   testRule (via `+`). You can only narrow permissions, never widen.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final principal = TissueQueueNucleus.create<String>(capacity: 10);
  /// final readOnlyNucleus = TissueQueueNucleusBase.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  ///   capacity: 5, // narrower capacity for this deputy
  /// );
  /// final readOnlyQueue = TissueQueue.fromNucleus(readOnlyNucleus);
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
  TissueQueueNucleusBase.evolve({
    super.override,
    required TissueQueueNucleus<E> super.principal,
  }) : super.evolve();

  /// Retrieves the hierarchical principal configuration of this queue's properties.
  ///
  /// This getter is a specialized, type‑safe override of the core [Nucleus.principal]
  /// link. It facilitates the "Property Cascading" mechanism that allows
  /// [TissueQueue] instances to participate in an inheritance‑based
  /// configuration model.
  ///
  /// ### When to use
  /// Only if you are building a custom queue implementation and need to
  /// traverse the inheritance chain to resolve a property value. For most
  /// application code, you never call this – the framework handles it for you.
  ///
  /// You rarely need to read this directly. The framework uses it internally
  /// when you create a deputy via `deputy()`. It's what makes a deputy "share"
  /// the same logic and storage as its principal.
  ///
  /// ### How it works
  /// 1. **Delegation**: If a property is requested but not explicitly defined
  ///    in the local [record], the system "walks up" this [principal] chain.
  /// 2. **Contextual Overrides**: A "Deputy" queue (created via `deputy()`)
  ///    typically has a [principal] link to the original queue's nucleus,
  ///    allowing it to inherit the physical data [container] and [capacity]
  ///    while providing a local override for the [context] or [testRule].
  /// 3. **Termination**: The chain ends when this getter returns `null` –
  ///    that's the "root" nucleus.
  ///
  /// ### Non‑obvious
  /// - The type is overridden to `TissueQueueNucleusBase<E, C>?` – a covariant
  ///   override that ensures you get a properly typed principal when you need
  ///   to access queue‑specific methods (like `capacity`).
  /// - Even though the getter is `public`, it's intended for internal
  ///   framework use. Mutating or replacing the principal after construction
  ///   is not supported – the nucleus is immutable.
  /// - The principal chain determines the `capacity` and all other structural
  ///   properties; a deputy can override the capacity if explicitly allowed.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final queue = TissueQueue<int>(capacity: 10);
  /// final deputy = queue.deputy(testRule: TestTissue.readOnly);
  /// // deputy._nucleus.principal points back to queue._nucleus
  /// // So when deputy needs the capacity, it delegates to queue._nucleus.
  /// ```
  ///
  /// ### Returns:
  /// The parent nucleus that this configuration extends, or `null` if this is
  /// a root nucleus with no ancestors.
  @override
  TissueQueueNucleusBase<E,C>? get principal => super.principal as TissueQueueNucleusBase<E,C>?;

  /// The physical storage strategy – always [Container.queue] for queues.
  ///
  /// This getter resolves the [Container] type by walking up the `principal`
  /// chain. For a queue, it is fixed to [Container.queue] because the underlying
  /// storage must be a double‑ended buffer.
  ///
  /// ### When to use
  /// Read this to confirm that the collection is indeed a queue. This is mostly
  /// informational.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed at the root nucleus
  ///   and inherited by all deputies. A deputy cannot change a queue into a
  ///   different collection type.
  /// - Defaults to [Container.queue].
  @override
  Container get containerType {
    return get<Container>(() => record.mask.inhertiable.container, fallback: () => principal?.containerType, orElse: Container.queue);
  }

  /// The maximum element threshold (capacity) for this queue.
  ///
  /// This getter resolves the [capacity] by walking up the `principal` chain.
  /// It determines the maximum number of elements the queue can hold.
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
  /// - The capacity is **structural** – it is fixed at creation and inherited
  ///   by all deputies unless explicitly overridden via `evolve`.
  /// - The capacity is used for **backpressure regulation** – when the queue
  ///   is full, `add` operations may drop the oldest element or reject the new
  ///   one, depending on the specific `TissueQueue` implementation.
  /// - A value of `-1` means unbounded (no limit).
  @override
  int get capacity => get<int>(() => record.mask.others.capacity, fallback: () => principal?.capacity, orElse: -1);

}

/// Concrete implementation of a mutable reactive queue.
///
/// [_TissueQueue] is the live instance you get from factories like `TissueQueue()`.
/// It ties together the nucleus (logic) and the container (data) to provide
/// a fully reactive, thread‑safe queue with validation and event emission.
///
/// ### When to use
/// You never create this directly – use [TissueQueue] or one of its named
/// constructors (`TissueQueue.of`, `TissueQueue.fromNucleus`).
///
/// ### How it works
/// - It extends [TissueQueueBase] and provides the mutable implementation.
/// - It holds a [TissueQueueNucleus] that defines the queue's behaviour.
/// - It implements `deputy()` to create restricted views.
/// - It provides the `async` getter for non‑blocking operations.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue queue type.
class _TissueQueue<E,C extends TissueQueue<E>> extends TissueQueueBase<E,C> {

  _TissueQueue({
    int? capacity,

    Cell? bind,
    Context context = Context.system,
    TissueReceptor<E,C> receptor = TissueReceptor.passThrough,
    TestTissue<E,C> testRule = TestTissue.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : super(_TissueQueueNucleus<E,C>(
      capacity: capacity,

      bind: bind,
      context: context,
      receptor: receptor,
      testRule: testRule,
      synapses: synapses
  ));

  _TissueQueue.of(Iterable<E> elements, {
    int? capacity,

    Cell? bind,
    Context context = Context.system,
    TissueReceptor<E,C> receptor = TissueReceptor.passThrough,
    TestTissue<E,C> testRule = TestTissue.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : super(_TissueQueueNucleus<E,C>(
      capacity: capacity,

      bind: bind,
      context: context,
      receptor: receptor,
      testRule: testRule,
      synapses: synapses
  ), elements: elements);

  _TissueQueue.fromNucleus(TissueQueueNucleus<E> nucleus, {super.elements})
      : super(nucleus as TissueQueueNucleusBase<E,C>);

  @override
  Queue<R> cast<R>() {
    return _nucleus.container.store.cast<R>();
  }

  @override
  FutureOr<TissueQueue<E>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueQueueDeputy<E,C>._(this, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  late final TissueQueue<E> unmodifiable = _UnmodifiableTissueQueue<E,C>.view(this, unmodifiableElement: true);

}

/// The foundational reactive engine for all double‑ended buffers in the
/// `cell_tissue` ecosystem.
///
/// [TissueQueueBase] provides the concrete integration between the reactive
/// [TissueBase] framework and the standard Dart [Queue] interface. It uses
/// [TissueQueueMixin] (to implement the Queue contract) and the internal
/// [TissueBase] to create a high‑performance, governed, and observable
/// double‑ended buffer.
///
/// ### When to use
/// Only if you are extending the framework to build a custom queue variant
/// that requires precise control over the mutation pipeline or storage
/// behaviour. For standard use cases, the existing [TissueQueue] factories
/// are sufficient.
///
/// You never use this class directly. It is the base class for the internal
/// implementations that power both mutable queues (`_TissueQueue`) and read‑only
/// views (`_UnmodifiableTissueQueue`). Your interaction with queues is through
/// the factories on [TissueQueue].
///
/// ### How it works
/// - It extends [TissueBase] to inherit the core reactive lifecycle,
///   synchronisation domain, and nucleus‑container architecture.
/// - It mixes in [TissueQueueMixin], which provides the full [Queue] API and
///   routes all mutations through the `apply` command gateway.
/// - Every structural change (adding to either end, removing, clearing) is:
///   1. Validated against the [TestTissue] rules.
///   2. Applied atomically to the [Container] (a `Queue<E>`).
///   3. Dispatched as a [TissueEvent] to all observers.
/// - The underlying storage is a Dart `Queue<E>` with O(1) head/tail operations.
///
/// ### Non‑obvious
/// - **The `apply` Gateway**: All mutations are funnelled through `apply`.
///   This is a security boundary – deputies override `modifiable` to return
///   an empty set, rejecting any mutation attempt.
/// - **Capacity enforcement**: The [capacity] is enforced by the container's
///   `_queueAdd` logic – when the queue is full, adding a new element drops
///   the oldest (circular buffer behaviour).
/// - **Member‑level bubbling**: If the queue contains [Cell] elements, they
///   are automatically linked, so internal changes trigger [ElementUpdatedEvent]s.
///
/// ### Example (Internal Usage)
/// While you never instantiate this directly, understanding it helps you
/// reason about how `TissueQueue` works:
/// ```dart
/// final nucleus = TissueQueueNucleus.create<String>(capacity: 10);
/// final queue = _TissueQueue<String>(nucleus);
/// queue.add('A'); // Routed through `apply` -> validation -> pulse emission
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained in the queue.
/// - [C]: The specific [Tissue] implementation type (usually `TissueQueue<E>`),
///   allowing for type‑safe pulse processing within the hierarchy.
abstract class TissueQueueBase<E,C extends TissueQueue<E>>
    extends TissueBase<E,Queue<E>,C>
    with TissueQueueMixin<E,C>
    implements TissueQueue<E> {

  @override
  TissueQueueNucleusBase<E,C> get _nucleus => super._nucleus as TissueQueueNucleusBase<E,C>;

  /// The primary constructor for a reactive double‑ended queue, responsible for
  /// materialising a live [TissueQueue] instance from its behavioural blueprint.
  ///
  /// ### When to use
  /// You never call this constructor directly. It is invoked by the framework
  /// when you use the [TissueQueue], [TissueQueue.of], or [TissueQueue.fromNucleus]
  /// factories. The constructor is the engine that takes a [TissueQueueNucleusBase]
  /// (the immutable DNA) and brings it to life with an optional initial set of
  /// elements.
  ///
  /// You don't. This is an internal constructor. But understanding it helps
  /// you trust that queue creation is atomic, valid, and fully reactive from
  /// the very first element.
  ///
  /// ### How it works
  /// 1. **Blueprint binding**: It receives a [TissueQueueNucleusBase] that
  ///    holds the queue's capacity, security rules ([TestTissue]), command
  ///    processor ([TissueReceptor]), and execution context. This nucleus is
  ///    the "DNA" of the queue – it governs every mutation.
  /// 2. **Atomic ingestion**: If an [Iterable] of [elements] is provided, they
  ///    are ingested into the physical storage (a `Queue<E>`) **atomically**
  ///    under the nucleus's synchronisation lock. This ensures that no
  ///    observer can see a partially populated queue during construction.
  /// 3. **Validation**: Each element is validated against the nucleus's
  ///    `testRule` before it is added. If an element fails validation, it is
  ///    **not** added – the queue will contain only the valid elements from
  ///    the initial collection.
  /// 4. **Automatic linking**: Any element that implements [Cell] is
  ///    automatically linked to the queue's [Synapses]. This enables
  ///    **member‑level bubbling** – when a child cell changes, the queue
  ///    emits a corresponding [TissueEvent] so that observers of the queue
  ///    are notified.
  /// 5. **Capacity enforcement**: If the queue has a bounded capacity, the
  ///    ingestion respects it – if the initial elements exceed the capacity,
  ///    the behaviour depends on the container's `_queueAdd` strategy
  ///    (typically dropping the oldest elements to make room).
  ///
  /// ### Non‑obvious
  /// - **Nucleus cloning**: The [nucleus] is automatically **cloned** if it
  ///   is already activated (bound to another queue). This prevents two
  ///   independent queues from accidentally sharing the same synchronisation
  ///   lock or observer registry.
  /// - **Validation per element**: The `testRule` is applied to **each**
  ///   individual element during ingestion. If some elements are invalid, they
  ///   are silently dropped – no event is emitted for rejected elements.
  /// - **Initial state is silent**: The initial population does **not**
  ///   trigger any [TissueEvent] pulses. Observers see the populated queue as
  ///   if it had always been that way. Events are only emitted for mutations
  ///   that happen *after* construction.
  /// - **Linking is idempotent**: If the same [Cell] appears multiple times
  ///   in the initial elements, it is linked only once – the link is
  ///   deduplicated.
  /// - **Bounded queue behaviour**: For a queue with a fixed capacity,
  ///   ingestion of more elements than the capacity will cause the oldest
  ///   elements to be dropped **silently** – no event is emitted for the
  ///   dropped elements during initialisation.
  ///
  /// ### Parameters:
  /// - [nucleus]: **Required**. The immutable blueprint that defines the
  ///   queue's capacity, governance, and reactive behaviour.
  /// - [elements]: Optional initial elements to populate the queue. Each
  ///   element is validated and linked if it is a [Cell].
  ///
  /// ### Example (internal usage – how the framework creates a queue)
  /// ```dart
  /// // When you write `TissueQueue<int>()`, the framework does something like:
  /// final nucleus = TissueQueueNucleus.create<int>(capacity: 10);
  /// final queue = TissueQueueBase<int, TissueQueue<int>>(nucleus);
  ///
  /// // With initial elements
  /// final queue = TissueQueueBase<int, TissueQueue<int>>(
  ///   nucleus,
  ///   elements: [1, 2, 3],
  /// );
  /// // Now the queue contains 1, 2, 3 (if they passed validation)
  /// ```
  TissueQueueBase(TissueQueueNucleusBase<E,C> super.nucleus, {super.elements}) : super();

  /// Returns an unmodifiable view of this queue.
  ///
  /// Subclasses must implement this to return a version of the queue that
  /// prevents direct mutation while reflecting changes made to the source.
  ///
  /// Returns:
  ///   An unmodifiable [TissueQueue<E>] instance.
  @override
  TissueQueue<E> get unmodifiable;

  /// Provides an asynchronous interface ([ModifiableQueueAsync]) for this queue.
  ///
  /// This allows queue modification operations (like `add` or `removeFirst`)
  /// to be performed asynchronously, integrating with the tissue's
  /// signaling system.
  ///
  /// Returns:
  ///   A [ModifiableQueueAsync<E>] instance bound to this queue.
  @override
  ModifiableQueueAsync<E> get async => ModifiableQueueAsync<E>(this);

  /// Returns the validation rule currently applied to this queue.
  ///
  /// This rule is checked by the [TissueQueueMixin] before elements
  /// are added to or removed from the underlying container.
  @override
  TestTissue<E, C> get validate => _nucleus.testRule;
}

/// Internal deputy implementation for [TissueQueue].
///
/// A deputy shares the same physical data as its principal but applies
/// different validation, context, or synapses. It is created via the
/// `deputy()` method on a [TissueQueue].
///
/// ### When to use
/// This is an internal class. You obtain deputies via the `deputy()` method on
/// any [TissueQueue] – you never instantiate this directly.
///
/// ### How it works
/// - It extends `_TissueQueue` and mixes in `Deputy`.
/// - The deputy's [TestTissue] is the composition of the principal's rule and
///   the deputy's additional rule (you can only narrow permissions).
/// - The deputy gets its own [Synapses] registry by default.
/// - The deputy is logically equal to its principal.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue queue type.
class _TissueQueueDeputy<E,C extends TissueQueue<E>> extends _TissueQueue<E,C> with Deputy<TissueQueue<E>> {

  _TissueQueueDeputy._(TissueQueueBase<E,C> bind, {Context context = Context.system, TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled})
      : super.fromNucleus(_TissueQueueNucleus<E,C>.evolve(
      override: _TissueQueueNucleus<E,C>(
        bind: bind,
        testRule: bind._nucleus.testRule + testRule,
        synapses: bind._nucleus.synapses != Synapses.disabled ? synapses : Synapses.disabled,
      ),
      principal: bind._nucleus)
  );

  @override
  FutureOr<TissueQueue<E>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueQueueDeputy<E,C>._(_nucleus.bind as TissueQueueBase<E,C>, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

}

/// Internal implementation of an unmodifiable (read‑only) reactive queue.
///
/// This is created when you call `.unmodifiable` on a [TissueQueue]. It
/// shares the same physical storage and lock as the source, but blocks all
/// mutation attempts. It is a live view – changes to the source are
/// immediately reflected.
///
/// ### When to use
/// This is an internal class. You obtain unmodifiable views via the
/// `.unmodifiable` getter on any [TissueQueue] – you never instantiate
/// this directly.
///
/// ### How it works
/// - It extends [UnmodifiableTissueQueueBase] and provides the concrete
///   implementation.
/// - It shares the same physical storage and lock as the mutable source.
/// - The view is **live** – changes to the source are immediately reflected.
/// - If `unmodifiableElement` is `true`, child [Cell] elements are projected
///   as read‑only deputies.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue queue type.
class _UnmodifiableTissueQueue<E,C extends TissueQueue<E>> extends UnmodifiableTissueQueueBase<E,C> {

  _UnmodifiableTissueQueue(Iterable<E> elements, {bool unmodifiableElement = true, TissueQueueNucleus<E>? nucleus})
      : this.fromNucleus(
      (nucleus ?? TissueQueueNucleus.create<E,C>()) as TissueQueueNucleusBase<E,C>,
      unmodifiableElement: unmodifiableElement,
      elements: elements
  );

  _UnmodifiableTissueQueue.view(TissueQueue<E> bind, {Context? context, bool unmodifiableElement = true})
      : this.fromNucleus(TissueQueueNucleus.create<E,C>(bind: bind,
      capacity: bind._nucleus.capacity != -1 ? bind._nucleus.capacity : null,
      container: unmodifiableElement ? bind._nucleus.containerType : null,
      context: context,
      synapses: bind._nucleus.synapses == Synapses.disabled ? Synapses.disabled : Synapses.enabled,
      principal: bind._nucleus as TissueQueueNucleusBase<E,C>
  ), unmodifiableElement: unmodifiableElement,
      elements: unmodifiableElement ? bind.map<E>((e) => e is Cell ? e.unmodifiable as E : e) : null
  );

  _UnmodifiableTissueQueue.fromNucleus(TissueQueueNucleus<E> nucleus, {super.unmodifiableElement, super.elements})
      : super(nucleus as TissueQueueNucleusBase<E,C>);
  @override
  FutureOr<TissueQueue<E>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<E,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueQueueDeputy<E,C>._(this as TissueQueueBase<E,C>, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  TestTissue<E,C> get validate => _nucleus.testRule;

}

/// The foundational base class for all read‑only reactive queue views.
///
/// [UnmodifiableTissueQueueBase] is the abstract anchor for unmodifiable
/// queue implementations (e.g., `_UnmodifiableTissueQueue`). It ties together
/// a read‑only nucleus and a shared storage container, ensuring that all
/// mutations are blocked while reactivity remains live.
///
/// ### When to use
/// Only if you are building a custom read‑only queue variant that needs
/// to override the default unmodifiable behaviour. For everyday use,
/// the existing `.unmodifiable` getter is all you need.
///
/// This class is **abstract** – you never instantiate it directly.
/// You obtain an unmodifiable queue by calling `.unmodifiable` on any
/// mutable [TissueQueue], or by using one of the dedicated factories
/// (`UnmodifiableTissueQueue`, `UnmodifiableTissueQueue.view`, etc.).
///
/// ### How it works
/// 1. The constructor receives a [TissueQueueNucleusBase] that defines the
///    queue's structural strategy (capacity) and governance rules.
/// 2. The `unmodifiableElement` flag controls deep immutability:
///    - If `true`, any element that is a [Cell] is automatically projected
///      as its `.unmodifiable` deputy when accessed via this queue.
///    - If `false`, child cells remain mutable (but the queue itself is
///      still read‑only).
/// 3. The queue shares the same physical storage as its mutable source
///    (when created via `.view`) – changes to the source are immediately
///    reflected in this read‑only view.
///
/// ### Non‑obvious
/// - **It is not a snapshot**: The view is live. Changes to the mutable
///   source are instantly visible.
/// - **Equality**: `source == source.unmodifiable` is `true` – they are
///   considered the same logical entity.
/// - **Recursive projection**: If `unmodifiableElement` is `true`, the
///   iterator wraps each element that is a [Cell] in its `.unmodifiable`
///   deputy, preventing side‑door mutations.
/// - **Own observer registry**: The view has its own [Synapses] registry,
///   so observers attached to the view are independent of those on the
///   source.
///
/// ### Example (Internal)
/// ```dart
/// final source = TissueQueue<int>();
/// source.add(1);
/// final readOnly = _UnmodifiableTissueQueue<int>.view(source);
/// // readOnly.add(2); // throws UnsupportedError
/// source.add(2); // readOnly now contains [1, 2]
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained in the queue.
/// - [C]: The specific [TissueQueue] implementation type (usually `TissueQueue<E>`).
abstract class UnmodifiableTissueQueueBase<E,C extends TissueQueue<E>>
    extends UnmodifiableTissueBase<E,Queue<E>,C>
    with TissueQueueMixin<E,C>
    implements UnmodifiableTissueQueue<E> {

  @override
  TissueQueueNucleusBase<E,C> get _nucleus => super._nucleus as TissueQueueNucleusBase<E,C>;

  /// Initializes a new [UnmodifiableTissueQueueBase] instance, anchoring
  /// a read‑only reactive queue (Double‑Ended Buffer) to its behavioral and
  /// structural blueprint.
  ///
  /// This constructor is the internal structural initializer for the
  /// unmodifiable queue hierarchy. It bridges the gap between the
  /// [TissueQueueNucleusBase] configuration and the live reactive
  /// infrastructure, ensuring that the queue enters the graph with an
  /// established "Read-Only" barrier.
  ///
  /// ### When to use
  /// This is an internal constructor. You don't call it directly. It is
  /// invoked by the unmodifiable queue factories.
  ///
  /// ### How it works
  /// 1. **Logic Activation**: It binds the provided property record to the
  ///    queue instance, activating the synchronization lock and execution
  ///    context required for reactive operations.
  /// 2. **Immutability Enforcement**: It prepares the instance to strictly
  ///    prohibit structural changes, ensuring that any attempt to mutate
  ///    the queue is intercepted and denied.
  /// 3. **Recursive Safety**: The `unmodifiableElement` flag establishes
  ///    the policy for deep immutability. If enabled, member elements that
  ///    are themselves reactive cells are accessed only as read‑only deputies.
  /// 4. **Pre‑computed Storage**: If [elements] are provided, the constructor
  ///    creates a dedicated storage container, bypassing lazy projection
  ///    logic for optimal iteration speed.
  ///
  /// ### Non‑obvious
  /// - The view has its own [Synapses] registry, so observers attached to
  ///   the view are independent of those on the source.
  /// - The `unmodifiableElement` flag affects deep immutability only – the
  ///   queue itself is always read‑only regardless of this flag.
  /// - Pre‑resolved unmodifiable proxies of member cells optimise iteration
  ///   speed for high‑frequency read operations in the UI layer.
  ///
  /// ### Parameters:
  /// - [nucleus]: **Required**. The [TissueQueueNucleusBase] defining
  ///   the queue's structural strategy, its synchronization domain, and its
  ///   reactive blueprint.
  /// - [unmodifiableElement]: A boolean flag. When true, reactive elements
  ///   retrieved from the queue are automatically projected as unmodifiable deputies.
  /// - [elements]: Optional. A pre‑mapped set of elements used to seed a
  ///   dedicated high‑performance storage container for this specific instance.
  UnmodifiableTissueQueueBase(
      TissueQueueNucleusBase<E,C> super.nucleus, {
        super.unmodifiableElement, Iterable<E>? elements}) : super(elements: elements) {
    final container = get<Container?>(() => _nucleus.record.mask.container, orElse: null);
    if (container != null && elements != null) {
      _nucleus.container.store.addAll(elements);
    }
  }

  /// Returns this instance, as it is already unmodifiable.
  ///
  /// ### Returns:
  ///   This [TissueQueue<E>] instance.
  @override
  TissueQueue<E> get unmodifiable => this;

  /// Returns an asynchronous interface for this queue.
  ///
  /// Since this queue is unmodifiable, the returned [ModifiableQueueAsync]
  /// instance will reject or ignore any attempts to modify the underlying data.
  ///
  /// ### Returns:
  ///   A [_UnmodifiableModifiableQueueAsync] instance.
  @override
  ModifiableQueueAsync<E> get async => const _UnmodifiableModifiableQueueAsync();

  @override
  TestTissue<E,C> get validate => _nucleus.testRule;

}

/// A mixin that provides queue operations for [TissueBase] implementations.
///
/// This mixin implements the [Queue] interface and adds reactive capabilities
/// to standard queue operations. All modifications to the queue are validated
/// through the tissue's test rules before being applied, and changes are
/// propagated through the receptor system.
///
/// ### When to use
/// Only if you are building a custom queue implementation that needs to reuse
/// the standard Queue logic.
///
/// This mixin is used internally by `TissueQueueBase` and
/// `UnmodifiableTissueQueueBase`. You don't interact with it directly – it
/// provides the Queue API for tissues.
///
/// ### How it works
/// - It requires the host class to provide `_nucleus` (a `TissueQueueNucleusBase`)
///   and `validate` (a `TestTissue`).
/// - It implements all Queue methods (`add`, `addFirst`, `removeLast`, `clear`,
///   etc.) by routing them through the `apply` gateway.
/// - The `apply` method validates the action and then calls the appropriate
///   private `_` method (e.g., `_add`, `_addFirst`) which updates the container
///   and emits the corresponding `TissueEvent`.
/// - The mixin also defines the `modifiable` set, which includes all mutation
///   functions that can be invoked via `apply`.
///
/// ### Non‑obvious
/// - The mixin does **not** hold any state itself – all state is in the nucleus.
/// - The private `_` methods (e.g., `_add`) are responsible for the actual
///   container mutation and event emission.
/// - If the host class is [Unmodifiable], the mutation methods are bypassed
///   (the host's `modifiable` is empty), so the mixin's mutation logic is
///   never reached.
/// - The `add` operation for a bounded queue uses the container's `_queueAdd`
///   strategy, which drops the oldest element when the queue is full
///   (circular buffer behaviour).
mixin TissueQueueMixin<E,C extends TissueQueue<E>>
// on TissueBase<E,Queue<E>,C>
implements TissueQueue<E> {

  @override
  TissueQueueNucleusBase<E,C> get _nucleus;


  @override
  Iterable<Function> get modifiable => <Function>{
    add,
    addAll,
    clear,
    remove,
    removeWhere,
    retainWhere,
    removeLast,
    // ...super.modifiable
  };

  //

  @override
  int get length => _nucleus.container.length;

  @override
  Queue<R> cast<R>() => _nucleus.container.store.cast<R>();

  //

  @override
  void add(E value) => apply(add, positionalArguments: [value]);

  @override
  void addAll(Iterable<E> iterable) => apply(addAll, positionalArguments: [iterable]);

  @override
  void addFirst(E value) => apply(addFirst, positionalArguments: [value]);

  @override
  void addLast(E value) => apply(addLast, positionalArguments: [value]);

  @override
  void clear() => apply(clear);

  @override
  bool remove(Object? object) => apply(remove, positionalArguments: [object]).isNotEmpty;

  @override
  E removeFirst() => apply(removeFirst).values.first.first;

  @override
  E removeLast() => apply(removeLast).values.first.first;

  @override
  void removeWhere(bool Function(E element) test) => apply(removeWhere, positionalArguments: [test]);

  @override
  void retainWhere(bool Function(E element) test) => apply(retainWhere, positionalArguments: [test]);

  //

  ElementAddedEvent<E>? _add(E value, {bool notification = true, Tissue<E>? deputy}) {
    ElementAddedEvent<E>? event;

    if (this is! Unmodifiable && modifiable.contains(add)) {
      if (validate.action(add, host: this, arguments: (positionalArguments: [value], namedArguments: null)) == true) {
        if (validate.element(value, host: this, action: add) == true && _nucleus.container.add(this,value)) {
          event = ElementAddedEvent<E>._(source: deputy ?? this, payload: value);
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }

  ElementAddedEvent<E>? _addFirst(E value, {bool notification = true, Tissue<E>? deputy}) {
    ElementAddedEvent<E>? event;

    if (this is! Unmodifiable && modifiable.contains(addFirst)) {
      if (validate.action(addFirst, host: this, arguments: (positionalArguments: [value], namedArguments: null)) == true) {
        if (validate.element(value, host: this, action: addFirst) == true) {
          _nucleus.container.store.addFirst(value);

          if (value is Cell && !_nucleus.container.contains(value)) {
            _nucleus.synapses.link(value, downstreamCell: this);
          }

          event = ElementAddedEvent<E>._(source: deputy ?? this, payload: value);
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }

  ElementAddedEvent<E>? _addLast(E value, {bool notification = true, Tissue<E>? deputy}) {
    ElementAddedEvent<E>? event;

    if (this is! Unmodifiable && modifiable.contains(addLast)) {
      if (validate.action(addLast, host: this, arguments: (positionalArguments: [value], namedArguments: null)) == true) {
        if (validate.element(value, host: this, action: addLast) == true) {
          _nucleus.container.store.addLast(value);

          if (value is Cell && !_nucleus.container.contains(value)) {
            _nucleus.synapses.link(value, downstreamCell: this);
          }

          event = ElementAddedEvent<E>._(source: deputy ?? this, payload: value);
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }

  ElementAddedEvent<Iterable<E>>? _addAll(Iterable<E> elements, {bool notification = true, Tissue<E>? deputy}) {
    ElementAddedEvent<Iterable<E>>? event;

    if (this is! Unmodifiable && modifiable.contains(addAll)) {
      if (validate.action(addAll, host: this, arguments: (positionalArguments: [elements], namedArguments: null)) == true) {
        final adds = elements.where((e) => validate.element(e, host: deputy is TissueQueue<E> ? deputy : this, action: add) == true);
        final added = adds.where((e) => _nucleus.container.add(this,e));
        if (added.isNotEmpty) {
          event = ElementAddedEvent<Iterable<E>>._(source: deputy ?? this, payload: added.toList(growable: false));
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }

  ElementRemovedEvent<Iterable<E>>? _clear({bool notification = true, Tissue<E>? deputy}) {
    ElementRemovedEvent<Iterable<E>>? event;

    if (this is! Unmodifiable && modifiable.contains(clear)) {
      if (validate.action(clear, host: this) == true) {
        final removes = _nucleus.container.where((e) => validate.element(e, host: deputy is TissueQueue<E> ? deputy : this, action: remove) == true);
        final removed = removes.where((e) => _nucleus.container.remove(this,e));
        if (removed.isNotEmpty) {
          event = ElementRemovedEvent<Iterable<E>>._(source: deputy ?? this, payload: removed.toList(growable: false));
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }

  ElementRemovedEvent<E>? _remove(Object? object, {bool notification = true, Tissue<E>? deputy}) {
    ElementRemovedEvent<E>? event;

    if (this is! Unmodifiable && modifiable.contains(remove)) {
      if (object != null && validate.action(remove, host: this, arguments: (positionalArguments: [object], namedArguments: null)) == true) {
        final e = firstWhere((e) => e == object);
        if (e != null && validate.element(e, host: deputy is TissueQueue<E> ? deputy : this, action: remove) == true && _nucleus.container.remove(this,e)) {
          event = ElementRemovedEvent<E>._(source: deputy ?? this, payload: e);
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }

  ElementRemovedEvent<E>? _removeFirst({bool notification = true, Tissue<E>? deputy}) {
    ElementRemovedEvent<E>? event;

    if (this is! Unmodifiable && modifiable.contains(removeLast)) {
      if (validate.action(removeFirst, host: this) == true) {
        final e = _nucleus.container.last;
        if (validate.element(e, host: deputy is TissueQueue<E> ? deputy : this, action: removeFirst) == true && _nucleus.container.remove(this, _nucleus.container.store.firstWhere((i) => e == i))) {
          if (e is Cell && !_nucleus.container.contains(e)) {
            _nucleus.synapses.unlink(e,downstreamCell: this);
          }
          event = ElementRemovedEvent<E>._(source: deputy ?? this, payload: e);
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }

  ElementRemovedEvent<E>? _removeLast({bool notification = true, Tissue<E>? deputy}) {
    ElementRemovedEvent<E>? event;

    if (this is! Unmodifiable && modifiable.contains(removeLast)) {
      if (validate.action(removeLast, host: this) == true) {
        final e = _nucleus.container.last;
        if (validate.element(e, host: deputy is TissueQueue<E> ? deputy : this, action: removeLast) == true && _nucleus.container.remove(this, _nucleus.container.store.lastWhere((i) => e == i))) {
          if (e is Cell && !_nucleus.container.contains(e)) {
            _nucleus.synapses.unlink(e,downstreamCell: this);
          }
          event = ElementRemovedEvent<E>._(source: deputy ?? this, payload: e);
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }

  ElementRemovedEvent<Iterable<E>>? _removeWhere(bool Function(E element) test, {bool notification = true, Tissue<E>? deputy}) {
    ElementRemovedEvent<Iterable<E>>? event;

    if (this is! Unmodifiable && modifiable.contains(removeWhere)) {
      if (validate.action(removeWhere, host: this, arguments: (positionalArguments: [test], namedArguments: null)) == true) {
        final removes = _nucleus.container.where((e) => test(e) && validate.element(e, host: deputy is TissueQueue<E> ? deputy : this, action: remove) == true);
        final removed = removes.where((e) => _nucleus.container.remove(this,e));
        if (removed.isNotEmpty) {
          event = ElementRemovedEvent<Iterable<E>>._(source: deputy ?? this, payload: removed.toList(growable: false));
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }

  ElementRemovedEvent<Iterable<E>>? _retainWhere(bool Function(E element) test, {bool notification = true, Tissue<E>? deputy}) {
    ElementRemovedEvent<Iterable<E>>? event;

    if (this is! Unmodifiable && modifiable.contains(retainWhere)) {
      if (validate.action(retainWhere, host: this, arguments: (positionalArguments: [test], namedArguments: null)) == true) {
        final removes = _nucleus.container.where((e) => !test(e) && validate.element(e, host: deputy is TissueQueue<E> ? deputy : this, action: remove) == true);
        final removed = removes.where((e) => _nucleus.container.remove(this,e));
        if (removed.isNotEmpty) {
          event = ElementRemovedEvent<Iterable<E>>._(source: deputy ?? this, payload: removed.toList(growable: false));
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }
    return event;
  }


  @override
  dynamic apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
  }) {

    if (validate.action(function, host: this, arguments: (positionalArguments: positionalArguments, namedArguments: namedArguments)) == true) {

      final notification = namedArguments?[#$notification] ?? true;

      if (function == add) {
        return Function.apply(_add, positionalArguments, {#notification: notification});
      }
      else if (function == addFirst) {
        return Function.apply(_addFirst, positionalArguments, {#notification: notification});
      }
      else if (function == addLast) {
        return Function.apply(_addLast, positionalArguments, {#notification: notification});
      }
      else if (function == addAll) {
        return Function.apply(_addAll, positionalArguments, {#notification: notification});
      }
      else if (function == clear) {
        return Function.apply(_clear, null, {#notification: notification});
      }
      else if (function == remove) {
        return Function.apply(_remove, positionalArguments, {#notification: notification});
      }
      else if (function == removeFirst) {
        return Function.apply(_removeFirst, positionalArguments, {#notification: notification});
      }
      else if (function == removeLast) {
        return Function.apply(_removeLast, positionalArguments, {#notification: notification});
      }
      else if (function == removeWhere) {
        return Function.apply(_removeWhere, positionalArguments, {#notification: notification});
      }
      else if (function == retainWhere) {
        return Function.apply(_retainWhere, positionalArguments, {#notification: notification});
      }
      return Function.apply(function, positionalArguments, namedArguments);
    }
  }

}

/// An asynchronous facade for performing reactive mutation operations on a [TissueQueue].
///
/// `ModifiableQueueAsync` provides a [Future]‑based API that mirrors the standard
/// mutation methods of a [TissueQueue]. This class is essential for scenarios
/// where queue modifications need to be offloaded to the event loop or handled
/// within an `async/await` workflow.
///
/// ### When to use
/// - You are in an `async` context (e.g., a network callback) and need to
///   wait for the mutation to be fully processed.
/// - You want to avoid blocking the UI thread during a batch of updates.
/// - The mutation involves I/O or other asynchronous side‑effects.
///
/// You never construct this directly. It is returned by the `async` getter
/// on any [TissueQueue] (e.g., `myQueue.async`). Use it when you need to
/// perform asynchronous mutations.
///
/// ### How it works
/// - It wraps the synchronous mutation methods (like `add`, `removeFirst`,
///   `clear`, etc.) in a `Future`.
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
/// - For bounded queues, the `add` operation respects the capacity – if the
///   queue is full, the operation may drop the oldest element or reject the
///   new one (depending on the implementation).
///
/// ### Example
/// ```dart
/// final queue = TissueQueue<int>(capacity: 10);
/// await queue.async.add(42);
/// print('Item added and all observers notified.');
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of elements contained within the queue.
///
/// See also:
/// - [TissueQueue.async] – the typical way to access an instance of this class.
/// - [TissueModifiableAsync] – the base class providing common async wrapping.
/// ```
class ModifiableQueueAsync<E> extends TissueModifiableAsync<E,TissueQueue<E>> {

  /// Creates an asynchronous callable wrapper for a [TissueQueue].
  ///
  /// This constructor is typically not called directly. Instead, instances are
  /// accessed via the [TissueQueue.async] getter.
  ///
  /// ### Parameters:
  ///   - `tissue`: The [TissueQueue<E>] whose operations will be wrapped.
  const ModifiableQueueAsync(super.tissue);


  /// Asynchronously adds [value] to the end of the associated [TissueQueue].
  ///
  /// This method wraps the synchronous `_tissue.add(value)` call in a [Future].
  ///
  /// ### Parameters:
  ///   - [value]: The element to add to the queue.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the add operation on the
  ///   underlying queue (including any reactive updates) has finished.
  Future<void> add(E value) async {
    return Future<void>(() => _tissue.add(value));
  }

  /// Asynchronously adds all elements of the [iterable] to the end of the
  /// associated [TissueQueue].
  ///
  /// This method wraps the synchronous `_tissue.addAll(iterable)` call in a [Future].
  ///
  /// ### Parameters:
  ///   - [iterable]: The [Iterable<E>] of elements to add.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the addAll operation on the
  ///   underlying queue (including any reactive updates) has finished.
  Future<void> addAll(Iterable<E> iterable) async {
    return Future<void>(() => _tissue.addAll(iterable));
  }

  /// Asynchronously adds the [value] to the beginning of the associated [TissueQueue].
  ///
  /// The provided code snippet for this method within the `ModifiableQueueAsync` class
  /// shows it throwing an `UnsupportedError`. This suggests that for the specific
  /// `TissueQueue` instance this `ModifiableQueueAsync` object is wrapping (or if this
  /// `ModifiableQueueAsync` is an unmodifiable variant like `_UnmodifiableModifiableQueueAsync`),
  /// the `addFirst` operation is not supported or not implemented for asynchronous execution.
  /// A typical modifiable implementation would wrap `_tissue.addFirst(value)`.
  ///
  /// ### Parameters:
  ///   - [value]: The element to add to the front of the queue.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the operation is attempted.
  ///   If the operation is unsupported by the specific underlying queue or this async wrapper,
  Future<void> addFirst(E value) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }


  /// Asynchronously adds the [value] to the end of the associated [TissueQueue].
  ///
  /// Similar to `addFirst`, the provided code snippet for this method within the
  /// `ModifiableQueueAsync` class shows it throwing an `UnsupportedError`.
  /// A typical modifiable implementation would wrap `_tissue.addLast(value)`.
  ///
  /// ### Parameters:
  ///   - [value]: The element to add to the end of the queue.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the operation is attempted.
  Future<void> addLast(E value) {
    return Future<void>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  /// Asynchronously removes all elements from the associated [TissueQueue].
  ///
  /// This method wraps the synchronous `_tissue.clear()` call in a [Future].
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the clear operation on the
  ///   underlying queue (including any reactive updates) has finished.
  Future<void> clear() async {
    return Future<void>(() => _tissue.clear());
  }

  /// Asynchronously removes a single instance of [value] from the associated [TissueQueue].
  ///
  /// This method wraps the synchronous `_tissue.remove(value)` call in a [Future].
  ///
  /// ### Parameters:
  ///   - [value]: The element to remove. Can be `null` if the queue supports null elements.
  ///
  /// ### Returns:
  ///   A [Future<bool>] that completes with `true` if [value] was found and removed
  ///   from the underlying queue, and `false` otherwise.
  Future<bool> remove(Object? value) async {
    return Future<bool>(() => _tissue.remove(value));
  }

  /// Asynchronously removes and returns the first element of the associated [TissueQueue].
  ///
  /// The provided code snippet for this method within the `ModifiableQueueAsync` class
  /// shows it throwing an `UnsupportedError`. A typical modifiable implementation would wrap
  /// `_tissue.removeFirst()`, which itself would throw a [StateError] if the queue is empty.
  ///
  /// ### Returns:
  ///   A [Future<E>] that completes with the element removed from the front of the queue.
  ///   It will complete with an [UnsupportedError] if the operation is not supported by this
  ///   async wrapper. If it were a modifiable wrapper, the Future could complete with a
  ///   [StateError] if the underlying queue is empty.
  Future<E> removeFirst() {
    return Future<E>(() => throw UnsupportedError('Unmodifiable operation'));
  }

  /// Asynchronously removes and returns the last element of the associated [TissueQueue].
  ///
  /// This method wraps the synchronous `_tissue.removeLast()` call in a [Future].
  /// The underlying `removeLast()` operation would typically throw a [StateError] if the
  /// queue is empty.
  ///
  /// ### Returns:
  ///   A [Future<E>] that completes with the element removed from the end of the queue.
  ///   The Future will complete with an error (e.g., [StateError] from the underlying
  ///   operation) if the queue is empty.
  Future<E> removeLast() {
    return Future<E>(() => _tissue.removeLast());
  }

  /// Asynchronously removes all elements from the associated [TissueQueue]
  /// that satisfy the given [test] predicate.
  ///
  /// This method wraps the synchronous `_tissue.removeWhere(test)` call in a [Future].
  ///
  /// ### Parameters:
  ///   - [test]: A function that takes an element and returns `true` if the element
  ///     should be removed.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the removeWhere operation on the
  ///   underlying queue (including any reactive updates) has finished.
  Future<void> removeWhere(bool Function(E element) test) async {
    return Future<void>(() => _tissue.removeWhere(test));
  }


  /// Asynchronously removes all elements from the associated [TissueQueue]
  /// that do *not* satisfy the given [test] predicate (i.e., it retains only elements
  /// for which [test] returns `true`).
  ///
  /// This method wraps the synchronous `_tissue.retainWhere(test)` call in a [Future].
  ///
  /// ### Parameters:
  ///   - [test]: A function that takes an element and returns `true` if the element
  ///     should be *retained*.
  ///
  /// ### Returns:
  ///   A [Future<void>] that completes after the retainWhere operation on the
  ///   underlying queue (including any reactive updates) has finished.
  Future<void> retainWhere(bool Function(E element) test) async {
    return Future<void>(() => _tissue.retainWhere(test));
  }

}

/// An unmodifiable async facade that throws [UnsupportedError] on any mutation.
///
/// This is returned by the `async` getter on unmodifiable queue views to
/// ensure that even asynchronous mutation attempts are rejected.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly.
///
/// ### How it works
/// - Every mutation method throws [UnsupportedError] with a descriptive
///   message indicating that the operation is not supported on unmodifiable
///   views.
class _UnmodifiableModifiableQueueAsync<E> implements ModifiableQueueAsync<E> {


  const _UnmodifiableModifiableQueueAsync();

  @override
  Future<void> add(E value) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override  Future<void> addAll(Iterable<E> iterable) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> addFirst(E value) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> addLast(E value) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> clear() async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<bool> remove(Object? value) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<E> removeFirst() async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<E> removeLast() async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> removeWhere(bool Function(E element) test) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  Future<void> retainWhere(bool Function(E element) test) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  @override
  TissueQueue<E> get _tissue => throw UnimplementedError();

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