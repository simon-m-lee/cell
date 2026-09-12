// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

// ignore_for_file: non_constant_identifier_names
// int get _RANDOM_PRIME => _$RANDOM_PRIME ??= <int>[2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97][Random().nextInt(24)];

/// A concrete implementation of a collective tissue event.
///
/// [_CollectiveTissueEvent] is the primary workhorse for batching multiple
/// [TissueEvent]s into a single atomic wave. It is instantiated by the
/// [TissueEvent.batch] factory and the `+` operator.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use
/// [TissueEvent.batch] or the `+` operator on any [TissueEvent].
///
/// ### How it works
/// - It extends [CollectiveTissueEventBase] and provides the concrete
///   implementation for batching tissue events.
/// - It stores the sub‑events in an immutable iterable in the payload.
/// - The `_branches` counter tracks completion of all sub‑events.
/// - The `+` operator flattens nested collectives into a single flat list.
///
/// ### Type Parameters:
/// * [E]: The type of the data payload.
class _CollectiveTissueEvent<E> extends CollectiveTissueEventBase<E> {

  _CollectiveTissueEvent(Iterable<TissueEvent<E>> events, {
  super.policy,
  super.type,
  super.context,
  super.timestamp,
  super.source,
  super.step,

  void Function(TissueEvent event)? super.onComplete,
  void Function(TissueEvent event, Object error, {StackTrace? stackTrace})? super.onError,
  void Function(TissueEvent event, Cell cell, {String? message})? super.onProgress,

  super.pulse,
  super.parent,

  super.priority,

  FutureOr<TissueEvent?> Function(TissueReceptor receptor)? super.scrutinize,
  }) : super(pulses: events);

}

/// The base implementation for a flat bundle of multiple independent
/// [TissueEvent]s that travel together as a single atomic wave.
///
/// ### When to use
/// You don't call this – you use the factories. But understanding it helps
/// you trust that batching works correctly:
/// - All sub‑events are stored in the [payload] as an immutable iterable.
/// - The collective itself is iterable, so you can loop over it.
/// - The `_branches` counter ensures that the `onComplete` callback fires
///   only after **all** sub‑events have finished propagating.
///
/// You never create this directly. It's the engine behind
/// [TissueEvent.batch] and the `+` operator. This class exists so that
/// collective events share a common implementation for payload storage,
/// iteration, and completion tracking.
///
/// ### How it works
/// - The constructor takes an iterable of `TissueEvent<E>` and stores them
///   in the payload.
/// - The `_branches` box (inherited from [PulseBase]) is incremented by one
///   for each sub‑event. When each sub‑event completes, it decrements the
///   counter. When the counter reaches zero, the collective's completion
///   callback fires.
/// - The [isComposite] flag is always `true`.
/// - The `+` operator flattens nested collectives – you always get a
///   single, flat list of events.
///
/// ### Non‑obvious
/// - The collective does **not** create a causal relationship between its
///   members. Each event keeps its own `parent` and `trace`.
/// - The collective's [root] is itself – it's a root collective.
/// - If the iterable is empty, the collective is still valid – it just has
///   `null` payload and `isComposite` `true`.
/// - Evolution (`evolve`) on a collective turns it into an
///   [EvolvedTissueEvent] (a chain), not another collective.
///
/// ### Example: Iterating over a batch
/// ```dart
/// final batch = CollectiveTissueEvent.from([addEvent, removeEvent]);
/// for (final event in batch) {
///   print(event.payload);
/// }
/// ```
///
/// ### Type Parameters:
/// - [E]: The type of the data payload – for a collective, this is the
///   type of the **first** pulse's payload (used for backward compatibility).
///
/// See also:
/// - [Pulse.batch] – the factory that creates Collective Pulses.
/// - [EvolvedPulse] – the chain-based composite created by `+`.
/// - [PulseBase] – the base class for all pulses.
abstract class CollectiveTissueEventBase<E>
    extends TissueEventBase<Iterable<Pulse<E>>>
    implements CollectiveTissueEvent<E>, CollectivePulse<E> {

  /// Creates a collective from the given [pulses] (which are actually
  /// `TissueEvent<E>` instances).
  ///
  /// ### When to use
  /// This is used internally by [TissueEvent.batch] and the `+` operator.
  /// You don't call it directly.
  ///
  /// ### How it works
  /// All metadata (type, context, priority, callbacks) is taken from the
  /// **first** event in the iterable. The `_branches` counter is initialised
  /// to the number of events.
  ///
  /// ### Parameters:
  /// - [pulses]: The events to bundle.
  /// - [policy], [type], [context], [timestamp], [source], [step]:
  ///   Optional overrides for the collective's metadata.
  /// - [onComplete], [onError], [onProgress]: Optional callbacks for the
  ///   entire batch.
  /// - [pulse], [parent], [scrutinize], [user], [priority]: Low‑level
  ///   pulse‑related fields (rarely used directly).
  CollectiveTissueEventBase({
    Iterable<TissueEvent<E>>? pulses,
    super.policy,
    super.type,
    super.context,
    super.timestamp,
    super.source,
    super.step,
    super.onComplete,
    super.onError,
    super.onProgress,
    super.pulse,
    super.parent,
    super.scrutinize,
    super.user,
    super.priority

  }) : super(payload: pulses) {
    final branches = _branches;
    if (branches != null) {
      branches.value = branches.value! + 1;
    }
  }

  /// The collection of events bundled in this collective.
  @override
  Iterable<TissueEvent<E>> get payload => super.payload as Iterable<TissueEvent<E>>;

  /// Returns an iterator over the sub‑events.
  ///
  /// This is what makes a collective usable in `for`‑loops and `Iterable`
  /// methods like `map` and `where`.
  @override
  Iterator<TissueEvent<E>> get iterator => payload.iterator;

  /// Combines this collective with another [TissueEvent] to create a new,
  /// flattened collective.
  ///
  /// ### When to use
  /// Use this to concatenate two batches into one flat batch.
  ///
  /// ### How it works
  /// - If [other] is a `CollectivePulse`, its events are extracted and
  ///   merged into the new collective.
  /// - Otherwise, [other] is appended as a single event.
  /// - The new collective contains a flat list of all events from both
  ///   operands.
  ///
  /// ### Example
  /// ```dart
  /// final batch1 = CollectiveTissueEvent.from([a, b]);
  /// final batch2 = CollectiveTissueEvent.from([c, d]);
  /// final combined = batch1 + batch2; // contains a, b, c, d
  /// ```
  ///
  /// ### Parameters:
  /// - [other]: The event or collective to combine with this one.
  ///
  /// ### Returns:
  /// A new [CollectiveTissueEvent] containing all events from both sources.
  @override
  CollectiveTissueEvent operator +(covariant TissueEvent other) {
    return other is TissueEvent<E>
        ? other is CollectivePulse<E>
        ? _CollectiveTissueEvent<E>([this as TissueEvent<E>, ...(other.payload as Iterable<TissueEvent<E>>)])
        : _CollectiveTissueEvent<E>([this as TissueEvent<E>, other])
        : other is CollectivePulse ? _CollectiveTissueEvent([this, ...other.payload]) : _CollectiveTissueEvent([this, other]);
  }

}

/// A concrete implementation of an evolved tissue event.
///
/// [_EvolvedTissueEvent] is the primary workhorse for creating causal chains
/// of [TissueEvent]s. It is instantiated by [TissueEvent.evolve] and
/// [TissueEvent.withStep].
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use
/// [TissueEvent.evolve] or [TissueEvent.withStep] on any [TissueEvent].
///
/// ### How it works
/// - It extends [EvolvedTissueEventBase] and provides the concrete
///   implementation for evolved events.
/// - It stores a reference to its [parent] and adds a [step] to the trace.
/// - The `_branches` counter tracks completion across the chain.
/// - The `+` operator creates a collective, not a longer chain.
///
/// ### Type Parameters:
/// * [E]: The type of the data payload.
class _EvolvedTissueEvent<E> extends EvolvedTissueEventBase<E> {

  _EvolvedTissueEvent({
  super.policy,
  super.payload,
  super.type,
  super.context,
  super.timestamp,
  super.source,
  super.step,
  void Function(TissueEvent event)? super.onComplete,
  void Function(TissueEvent event, Object error, {StackTrace? stackTrace})? super.onError,
  void Function(TissueEvent event, Cell cell, {String? message})? super.onProgress,
  super.pulse,
  super.parent,

  super.scrutinize,
  super.user,
}) : super();

}

/// The base implementation for a single [TissueEvent] that has been derived
/// from a previous event, preserving its full causal lineage.
///
/// ### When to use
/// You don't call this directly. But understanding it helps you trust that
/// evolution works correctly:
/// - The [parent] chain is immutable – once set, it never changes.
/// - The `trace` accumulates steps by walking the chain.
/// - The `_branches` counter ensures that completion callbacks fire correctly
///   even for evolved events.
///
/// You never create this directly. It's returned by [TissueEvent.evolve] or
/// [TissueEvent.withStep]. This class is the engine that builds the
/// parent‑child chain, records the `trace`, and keeps the `root` pointer
/// pointing to the original event.
///
/// ### How it works
/// - The constructor takes a mandatory [parent] (the immediate ancestor) and
///   optional [step] or [context] overrides.
/// - The new event links back to the parent via the `_parent` field.
/// - The [payload] is inherited from the root – evolved events don't
///   duplicate data.
/// - The `_branches` counter is incremented by one to track completion across
///   the chain.
///
/// ### Non‑obvious
/// - Unlike a [CollectiveTissueEvent], this is a **chain**, not a flat bundle.
///   The `+` operator on an evolved event creates a collective (a batch), not
///   a longer chain.
/// - The [parent] is never `null` – the root event (the original) is the only
///   one without a parent.
/// - When you call `evolve` again, you get a new `EvolvedTissueEvent` that
///   links back to the previous one.
///
/// ### Example: building a chain
/// ```dart
/// final root = ElementAddedEvent<int>(payload: 42);
/// final evolved = root
///     .withStep('validation')
///     .withStep('transformation');
/// // evolved is an EvolvedTissueEventBase.
/// ```
abstract class EvolvedTissueEventBase<E> extends _TissueEvent<E> with _TissueEventMixin<E> implements EvolvedPulse<E> {

  /// Creates an evolved event with the given parameters.
  ///
  /// ### When to use
  /// This is used internally by [TissueEvent.evolve] and [withStep].
  ///
  /// ### How it works
  /// The [parent] is mandatory – this event cannot exist in isolation.
  /// The [step] is appended to the causal trace.
  /// The [context] overrides the pulse's context for this specific step.
  ///
  /// ### Parameters:
  /// - [policy]: Optional lifecycle governance for the new event.
  /// - [payload]: Usually inherited from the parent; only set if explicitly
  ///   changing the payload (rare).
  /// - [type], [context], [timestamp], [source], [step], [priority]:
  ///   Metadata overrides.
  /// - [onComplete], [onError], [onProgress]: Callbacks for this specific
  ///   event (they are inherited up the chain).
  /// - [pulse]: An optional associated pulse.
  /// - [parent]: **Required** – the immediate ancestor in the causal chain.
  /// - [scrutinize], [user]: Low‑level fields for security and metadata.
  EvolvedTissueEventBase({
    super.policy,
    super.context,

    super.payload,
    super.type,
    super.timestamp,
    super.source,
    super.step,
    super.priority,

    super.onComplete,
    super.onError,
    super.onProgress,
    super.pulse,
    super.parent,

    super.scrutinize,
    super.user,
  }) : super();

  /// The immediate predecessor in the causal chain.
  ///
  /// This is never `null` for an evolved event.
  ///
  /// ### Returns:
  /// The parent event in the causal chain.
  @override
  TissueEventBase<E> get parent => _parent!;

  /// Combines this evolved event with another [TissueEvent] to create a
  /// [CollectiveTissueEvent].
  ///
  /// This does **not** create a longer chain – it bundles the two events
  /// into a flat batch. Each keeps its own independent history.
  ///
  /// ### When to use
  /// Use this to batch an evolved event with another event.
  ///
  /// ### Example
  /// ```dart
  /// final evolved = root.withStep('step1');
  /// final batch = evolved + anotherEvent; // CollectiveTissueEvent
  /// ```
  ///
  /// ### Parameters:
  /// - [other]: The event to combine with this evolved event.
  ///
  /// ### Returns:
  /// A [CollectiveTissueEvent] containing both events.
  @override
  CollectiveTissueEvent operator +(covariant TissueEvent other) {
    return other is TissueEvent<E>
        ? other is CollectivePulse<E>
        ? _CollectiveTissueEvent<E>([this, ...(other.payload as Iterable<TissueEvent<E>>)])
        : _CollectiveTissueEvent<E>([this, other])
        : other is CollectivePulse ? _CollectiveTissueEvent([this, ...other.payload]) : _CollectiveTissueEvent([this, other]);
  }

}

/// A concrete implementation of a standard (non‑composite) tissue event.
///
/// [_TissueEvent] is the primary workhorse for all non‑composite tissue events.
/// It is instantiated by the concrete event types like [ElementAddedEvent],
/// [ElementRemovedEvent], and [ValueChangedEvent].
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// concrete event types or the [TissueEvent] factories.
///
/// ### How it works
/// - It extends [TissueEventBase] and provides the concrete implementation.
/// - It implements `evolve()` to create evolved events.
/// - It implements `withStep()` to add steps to the trace.
/// - It provides the `shell` getter for defensive proxies.
/// - It provides the `unmodifiable` getter for read‑only projections.
///
/// ### Type Parameters:
/// * [E]: The type of the data payload.
class _TissueEvent<E> extends TissueEventBase<E> {

  _TissueEvent({
    super.policy,
    super.context,

    super.payload,
    super.type,
    super.timestamp,
    super.source,
    super.step,
    super.priority,

    super.onComplete,
    super.onError,
    super.onProgress,

    super.pulse,
    super.parent,

    FutureOr<TissueEvent?> Function(TissueReceptor receptor)? super.scrutinize,
    super.user,

  }) : super();

  const _TissueEvent.fromRecord(super.record) : super.fromRecord();

  /// Creates a new evolved event from this event.
  ///
  /// ### Parameters:
  /// - [pulse]: Optional pulse to associate with the new event.
  /// - [step]: Optional step description to add to the trace.
  /// - [context]: Optional context override for the new event.
  ///
  /// ### Returns:
  /// A new [EvolvedTissueEvent] linked to this event as its parent.
  @override
  TissueEvent evolve({Pulse? pulse, String? step, covariant PulseContext? context}) {
    return _EvolvedTissueEvent<E>(
      context: context,
      step: step,
      parent: this,
    );
  }

  /// Returns an iterator over the events in this chain.
  ///
  /// For a standard event, this returns an iterator over a single element.
  @override
  Iterator<Pulse<E>> get iterator {
    final events = super.toList(growable: false).cast<TissueEvent<E>>();
    return events.iterator;
  }

  /// Returns a defensive shell for this event.
  ///
  /// The shell hides the payload until the receiver authenticates itself.
  ///
  /// ### Returns:
  /// A [TissueEventShell] that gates access to the event.
  @override
  TissueEventShell<E> get shell => TissueEventShell<E>._(this);

  /// Returns a read‑only projection of this event.
  ///
  /// ### Returns:
  /// An [UnmodifiableTissueEvent] that blocks further evolution.
  @override
  TissueEventBase<E> get unmodifiable => _UnmodifiableTissueEvent<E>(this) as TissueEventBase<E>;

  /// Appends a step to the event's causal trace.
  ///
  /// ### Parameters:
  /// - [step]: The step description to add.
  ///
  /// ### Returns:
  /// A new [TissueEvent] with the updated trace.
  @override
  TissueEventBase<E> withStep(String step) => _TissueEvent<E>(step: step, parent: this);

}

/// A mixin that provides common tissue event behaviour.
///
/// [_TissueEventMixin] implements the shared methods for [TissueEvent]s:
/// - `shell` – defensive proxy.
/// - `evolve` – causal chaining.
/// - `withStep` – trace accumulation.
/// - `source` – originating tissue.
/// - `root` – primordial ancestor.
/// - `unmodifiable` – read‑only projection.
/// - `+` – batching operator.
/// - `_parent` – immediate ancestor.
///
/// ### When to use
/// This mixin is used by [TissueEventBase] and [EvolvedTissueEventBase] to
/// share common implementation.
mixin _TissueEventMixin<E> on Pulse<E> {

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  get _record;

  /// Returns a defensive shell for this event.
  ///
  /// The shell hides the payload until the receiver authenticates itself.
  ///
  /// ### Returns:
  /// A [TissueEventShell] that gates access to the event.
  @override
  TissueEventShell<E> get shell => TissueEventShell<E>._(this as TissueEventBase<E>);

  /// Creates a new event that is a child of this one.
  ///
  /// ### Parameters:
  /// - [pulse]: Optional pulse to associate with the new event.
  /// - [step]: Optional step description to add to the trace.
  /// - [context]: Optional context override for the new event.
  ///
  /// ### Returns:
  /// A new [EvolvedTissueEvent] linked to this event as its parent.
  @override
  TissueEvent evolve({Pulse? pulse, String? step, covariant PulseContext? context}) {
    return _EvolvedTissueEvent(
      context: context,
      step: step,
      pulse: pulse,
      parent: this as TissueEventBase<E>,
    );
  }

  /// Appends a step to the event's causal trace.
  ///
  /// ### Parameters:
  /// - [step]: The step description to add.
  ///
  /// ### Returns:
  /// A new [TissueEvent] with the updated trace.
  @override
  TissueEventBase<E> withStep(String step) {
    return _TissueEvent<E>(
      step: step,
      parent: this as TissueEventBase<E>,
    );
  }

  /// The tissue that originally emitted this event.
  ///
  /// ### Returns:
  /// The [Tissue] that caused this event, or `null` if unknown.
  @override
  Tissue? get source => super.source as Tissue?;

  /// The primordial ancestor of this event's causal lineage.
  ///
  /// ### Returns:
  /// The root event in the causal chain.
  @override
  TissueEventBase<E> get root => super.root as TissueEventBase<E>;

  /// Returns a read‑only projection of this event.
  ///
  /// ### Returns:
  /// An [UnmodifiableTissueEvent] that blocks further evolution.
  @override
  TissueEventBase<E> get unmodifiable {
    return _UnmodifiableTissueEvent<E>(this as TissueEventBase<E>) as TissueEventBase<E>;
  }

  /// Combines this event with another to create a [CollectiveTissueEvent].
  ///
  /// ### Parameters:
  /// - [other]: The event to combine with this one.
  ///
  /// ### Returns:
  /// A [CollectiveTissueEvent] containing both events.
  @override
  CollectiveTissueEvent operator +(covariant TissueEvent other) {
    return other is TissueEvent<E>
        ? other is CollectivePulse<E>
        ? _CollectiveTissueEvent<E>([this as TissueEvent<E>, ...(other.payload as Iterable<TissueEvent<E>>)])
        : _CollectiveTissueEvent<E>([this as TissueEvent<E>, other])
        : other is CollectivePulse ? _CollectiveTissueEvent([this as TissueEvent<E>, ...other.payload]) : _CollectiveTissueEvent([this as TissueEvent<E>, other]);
  }

  /// The immediate parent in the causal chain.
  ///
  /// ### Returns:
  /// The parent event, or `null` if this is the root.
  TissueEventBase<E>? get _parent {
    return get<TissueEventBase<E>?>(() => _record._parent, orElse: null);
  }

}

/// The foundational implementation for all [TissueEvent]s – the standard
/// signal that carries a collection change through the reactive graph.
///
/// ### When to use
/// You don't call this directly. But understanding it helps you trust that
/// every event carries accurate provenance:
/// - The payload is resolved by walking up the parent chain – evolved events
///   don't duplicate data.
/// - The `source` tells you which tissue originally emitted the event.
/// - The `trace` records every step the event has taken.
/// - The `_onComplete`, `_onError`, and `_onProgress` callbacks are stored on
///   the **root** event, so they fire even if the event is evolved multiple times.
///
/// You never create this directly. It's the base class for concrete events
/// like [ElementAddedEvent], [ElementRemovedEvent], and [ValueChangedEvent].
/// This class handles the heavy lifting: storing the payload, managing the
/// causal chain, resolving properties by walking up the `_parent` chain, and
/// firing lifecycle callbacks.
///
/// ### How it works
/// - It extends [PulseBase] to reuse the pulse's immutable record system
///   and causal chain machinery.
/// - It mixes in `_TissueEventMixin` to add the tissue‑specific behaviours:
///   `source` as a `Tissue`, `shell`, `withStep`, and the `+` operator.
/// - The constructor uses the same bitmask‑based `Record` pattern as
///   `PulseBase` – only non‑default fields are stored, saving memory.
/// - Property resolution (like `payload`, `context`, `source`) walks up the
///   `_parent` chain if the property is not defined locally.
/// - The `_branches` box tracks completion across composite events
///   (collectives and evolved chains).
///
/// ### Non‑obvious
/// - The `onComplete` callback is stored on the **root** of the chain.
///   If you attach a completion callback to a derived event, it replaces the
///   root's callback – so only the final callback in the chain matters.
/// - The `_branches` counter is used for **both** collectives and evolved
///   chains. It ensures that `onComplete` fires only after all branches
///   have finished.
/// - The `_progress` callback is fired by the receptor during processing –
///   you can use it to track long‑running operations.
/// - The `const TissueEventBase.type(String type)` constructor is a
///   performance optimisation for creating typed events with minimal overhead.
///
/// ### Example: creating a simple event
/// ```dart
/// // Using the main constructor
/// final event = ElementAddedEvent<int>._(payload: 42);
///
/// // Using the type‑optimised constructor
/// final typedEvent = TissueEventBase.type('my_event');
/// ```
abstract class TissueEventBase<E> extends PulseBase<E> with _TissueEventMixin<E> implements TissueEvent<E> {

  // ignore: prefer_typing_uninitialized_variables
  @override
  final _record;

  /// Primary constructor for a tissue event.
  ///
  /// ### When to use
  /// This is used by concrete event types (like `ElementAddedEvent`) to
  /// initialise their base fields. You don't call it directly.
  ///
  /// ### How it works
  /// All parameters are optional and default to `null`. The framework
  /// uses bitmasking to store only non‑default values, minimising memory
  /// overhead. The [scrutinize] parameter allows you to attach a custom
  /// authentication challenge to the event.
  ///
  /// ### Parameters:
  /// - [policy]: Lifecycle governance (TTL/hop limits) for the event.
  /// - [context]: Provenance metadata (actor, reason, priority, etc.).
  /// - [payload]: The actual data carried by the event.
  /// - [type]: A semantic tag for routing or filtering.
  /// - [source]: The [Tissue] that originated this event.
  /// - [timestamp]: When the event was created (defaults to now).
  /// - [step]: An optional description of the current processing stage.
  /// - [priority]: Execution urgency (0‑100).
  /// - [onComplete], [onError], [onProgress]: Lifecycle callbacks.
  /// - [pulse], [parent]: For causal chaining (evolved events).
  /// - [scrutinize]: A custom handshake function for defensive shells.
  /// - [user]: Arbitrary metadata for custom logic.
  TissueEventBase({

    PulseEphemeralPolicy? policy,
    PulseContext? context,

    E? payload,
    String? type,
    Tissue? source,
    DateTime? timestamp,

    String? step,
    int? priority,

    Function? onComplete, // void Function(TissueEvent event)? onComplete,
    Function? onError, // void Function(TissueEvent event, Object error, {StackTrace? stackTrace})? onError,
    Function? onProgress, // void Function(TissueEvent event, Cell cell, {String? message})? onProgress,

    Pulse<E>? pulse,
    TissueEvent<E>? parent,

    Function? scrutinize, // FutureOr<Pulse?> Function(TissueReceptor receptor)? scrutinize,
    dynamic user
  }) : this.fromRecord(
      PulseBase.mask(
        policy: policy,
        context: context,

        payload: payload,
        type: type,
        timestamp: timestamp,

        source: source,
        step: step,
        priority: priority,

        onComplete: onComplete,
        onError: onError,
        onProgress: onProgress,

        pulse: pulse,
        parent: parent,
        scrutinize: scrutinize,
        user: user,
      )
  );

  /// A specialised, memory‑optimised constructor for creating a typed event.
  ///
  /// Use this when you only need a [type] tag and no other metadata. It
  /// bypasses the full parameter list and stores only the type, making it
  /// extremely lightweight. This is ideal for high‑frequency events where
  /// you just need a label.
  ///
  /// ### When to use
  /// - You need a lightweight event with only a type tag.
  /// - You are creating high‑frequency events where metadata is not needed.
  /// - You want to minimise memory overhead for event creation.
  ///
  /// ### Example
  /// ```dart
  /// final event = TissueEventBase.type('user_logout');
  /// ```
  const TissueEventBase.type(String type)
      : this.fromRecord((root: (secondary: (type: type))));

  /// Low‑level constructor that takes a raw [Record].
  ///
  /// This is used internally for deserialisation and cloning. You never
  /// call it directly.
  const TissueEventBase.fromRecord(super.record) : _record = record, super.fromRecord();

  /// The branch completion counter for composite events.
  ///
  /// This is an internal box that tracks how many sub‑events in a composite
  /// (collective or evolved chain) still need to complete. When the counter
  /// reaches zero, the completion callback fires.
  ///
  /// ### When to use
  /// You never access this directly – it's used internally.
  ///
  /// ### Returns:
  /// A [Box<int>] containing the remaining branch count, or `null` if this
  /// is an atomic (non‑composite) event.
  Box<int>? get _branches {
    return get<Box<int>?>(() => _record.root.callbacks.branches, orElse: null);
  }

  /// Returns a defensive shell that hides the event's payload until the
  /// receiver authenticates itself.
  ///
  /// ### When to use
  /// Use this when you need to send an event to untrusted code – the shell
  /// forces the receiver to prove its identity before accessing the payload.
  ///
  /// ### Example
  /// ```dart
  /// final shell = myEvent.shell;
  /// ```
  ///
  /// ### Returns:
  /// A [TissueEventShell] that gates access to the event.
  @override
  TissueEventShell<E> get shell => TissueEventShell<E>._(this);

  /// Creates a new event that is a child of this one, preserving the
  /// causal chain.
  ///
  /// This is the primary way to record a processing step. You can optionally
  /// change the [context] or attach a related [pulse].
  ///
  /// ### When to use
  /// - You've transformed the event's payload and want to record that step.
  /// - You need to add a new step to the audit trail.
  /// - You want to change the context (e.g., actor or reason) for the
  ///   next stage of processing.
  ///
  /// ### Example
  /// ```dart
  /// final evolved = event.evolve(step: 'validated', context: newContext);
  /// ```
  ///
  /// ### Parameters:
  /// - [pulse]: Optional pulse to associate with the new event.
  /// - [step]: Optional step description to add to the trace.
  /// - [context]: Optional context override for the new event.
  ///
  /// ### Returns:
  /// A new [EvolvedTissueEvent] linked to this event as its parent.
  @override
  TissueEvent evolve({Pulse? pulse, String? step, covariant PulseContext? context}) {
    return _EvolvedTissueEvent(
      context: context,
      step: step,
      pulse: pulse,
      parent: this,
    );
  }

  /// A convenience wrapper around [evolve] that only adds a step to the trace.
  ///
  /// This is the most common way to record a processing milestone.
  ///
  /// ### When to use
  /// - You want to add a breadcrumb to the event's audit trail.
  /// - You don't need to change the context or attach a pulse.
  ///
  /// ### Example
  /// ```dart
  /// final processed = event.withStep('transformation');
  /// ```
  ///
  /// ### Parameters:
  /// - [step]: The step description to add to the trace.
  ///
  /// ### Returns:
  /// A new [TissueEvent] with the updated trace.
  @override
  TissueEventBase<E> withStep(String step) {
    return _TissueEvent<E>(
      step: step,
      parent: this,
    );
  }

  /// The [Tissue] that originally emitted this event.
  ///
  /// This is resolved by walking up the parent chain. If not set locally,
  /// it delegates to the parent.
  ///
  /// ### Returns:
  /// The [Tissue] that caused this event, or `null` if unknown.
  @override
  Tissue? get source => super.source;

  /// The primordial ancestor that initiated this entire event lineage.
  ///
  /// This is resolved by walking up the parent chain to the very first event.
  ///
  /// ### Returns:
  /// The root event in the causal chain.
  @override
  TissueEventBase<E> get root => super.root;

  /// Returns a read‑only projection of this event that blocks further
  /// evolution and deeply projects any child [Cell]s as unmodifiable.
  ///
  /// ### When to use
  /// - Sharing an event with code that should only read it.
  /// - Auditing or logging where the event must remain unchanged.
  /// - Sending an event to a sandboxed environment.
  ///
  /// ### Example
  /// ```dart
  /// final readOnly = event.unmodifiable;
  /// ```
  ///
  /// ### Returns:
  /// An [UnmodifiableTissueEvent] that blocks further evolution.
  @override
  TissueEventBase<E> get unmodifiable {
    return _UnmodifiableTissueEvent<E>(this) as TissueEventBase<E>;
  }

  /// Combines this event with another to create a [CollectiveTissueEvent].
  ///
  /// This is the standard way to batch events. The resulting collective
  /// contains both events as independent members.
  ///
  /// ### When to use
  /// - You need to send multiple events as one atomic unit.
  /// - You want to batch changes from multiple operations.
  ///
  /// ### Example
  /// ```dart
  /// final batch = event1 + event2;
  /// ```
  ///
  /// ### Parameters:
  /// - [other]: The event to combine with this one.
  ///
  /// ### Returns:
  /// A [CollectiveTissueEvent] containing both events.
  @override
  CollectiveTissueEvent operator +(covariant TissueEvent other) {
    return other is TissueEvent<E>
        ? other is CollectivePulse<E>
        ? _CollectiveTissueEvent<E>([this as TissueEvent<E>, ...(other.payload as Iterable<TissueEvent<E>>)])
        : _CollectiveTissueEvent<E>([this as TissueEvent<E>, other])
        : other is CollectivePulse ? _CollectiveTissueEvent([this as TissueEvent<E>, ...other.payload]) : _CollectiveTissueEvent([this as TissueEvent<E>, other]);
  }

  /// The immediate parent in the causal chain.
  ///
  /// ### Returns:
  /// The parent event, or `null` if this is the root.
  @override
  TissueEventBase<E>? get _parent {
    return get<TissueEventBase<E>?>(() => _record._parent, orElse: null);
  }

  // ───── Internal Callbacks (stored on the root) ─────

  /// The completion callback, invoked when the event has been fully processed.
  ///
  /// ### Returns:
  /// The completion callback function, or `null` if not set.
  void Function(TissueEvent event)? get _onComplete {
    return get<void Function(TissueEvent event)?>(
            () => _record.root.callbacks.onComplete,
        fallback: () => _parent?._onComplete,
        orElse: null);
  }

  /// The error callback, invoked if processing fails.
  ///
  /// ### Returns:
  /// The error callback function, or `null` if not set.
  void Function(TissueEvent event, Object error, {StackTrace? stackTrace})? get _onError {
    return get<void Function(TissueEvent event, Object error, {StackTrace? stackTrace})?>(
            () => _record.root.callbacks.onError,
        fallback: () => _parent?._onError,
        orElse: null);
  }

  /// The progress callback, invoked during long‑running operations.
  ///
  /// ### Returns:
  /// The progress callback function, or `null` if not set.
  void Function(TissueEvent event, Cell cell, {String? message})? get _onProgress {
    return get<void Function(TissueEvent event, Cell cell, {String? message})?>(
            () => _record.root.callbacks.onProgress,
        fallback: () => _parent?._onProgress,
        orElse: null);
  }

  /// Safely fires the completion callback on the root.
  void _complete() {
    root._onComplete?.call(this);
  }

  /// Safely fires the error callback on the root.
  void _fail(Object error, {StackTrace? stackTrace}) {
    root._onError?.call(this, error, stackTrace: stackTrace);
  }

  /// Safely fires the progress callback on the root.
  void _progress(Cell cell, {String? message}) {
    root._onProgress?.call(this, cell, message: message);
  }

}

/// A concrete implementation of an unmodifiable tissue event.
///
/// [_UnmodifiableTissueEvent] is the primary implementation of the
/// `.unmodifiable` getter on [TissueEvent]s. It provides a read‑only
/// projection that blocks further evolution.
///
/// ### When to use
/// This is an internal class. You obtain unmodifiable views via the
/// `unmodifiable` getter on any [TissueEvent] – you never instantiate
/// this directly.
///
/// ### How it works
/// - It extends [UnmodifiableTissueEventBase] and provides the concrete
///   implementation.
/// - It wraps the source event and delegates all read operations to it.
/// - It blocks evolution and mutation through the same interface.
///
/// ### Type Parameters:
/// * [E]: The type of the data payload.
class _UnmodifiableTissueEvent<E> extends UnmodifiableTissueEventBase<E> {

  _UnmodifiableTissueEvent(TissueEvent<E> source) : super(source as TissueEventBase<E>);

}

/// A read‑only, immutable projection of a [TissueEvent] that guarantees no
/// further evolution or mutation.
///
/// ### When to use
/// - Logging or serialising an event for auditing.
/// - Passing an event to a UI component that should only display data.
/// - Sending an event to a sandboxed or untrusted environment.
///
/// You never create this directly. It's returned by [TissueEvent.unmodifiable].
/// Use it when you need to share an event with code that should only read
/// its data but never derive new events from it.
///
/// ### How it works
/// - It wraps the source event and delegates all read operations to it.
/// - Any [Cell] in the payload is automatically projected as its
///   `.unmodifiable` deputy when accessed.
/// - The causal chain ([parent], [root], [source]) is also projected as
///   unmodifiable.
/// - Unlike a true immutable wrapper, this **does** allow evolution –
///   but evolution creates a **new** event, it does not mutate this one.
///   This is because the unmodifiable projection is a view, not a final
///   barrier to derivation.
/// - The `+` operator combines this event into a collective.
///
/// ### Non‑obvious
/// - This is a zero‑copy projection – the underlying data is not duplicated.
/// - It is recursive: `parent` and `root` are also unmodifiable projections.
/// - For composite events (collectives), iteration yields unmodifiable
///   projections of each sub‑event.
/// - The [shell] getter on an unmodifiable event still works – it wraps
///   the projection in a defensive shell.
///
/// ### Example
/// ```dart
/// final event = ElementAddedEvent<int>(payload: 42);
/// final readOnly = event.unmodifiable;
///
/// // readOnly.evolve(step: 'new'); // creates a NEW event, doesn't mutate
/// print(readOnly.payload); // 42 (safe to read)
/// ```
abstract class UnmodifiableTissueEventBase<E> extends UnmodifiablePulseBase<E> implements UnmodifiableTissueEvent<E>, TissueEventBase<E> {

  /// The underlying source event that this projection wraps.
  final TissueEventBase<E> _source;

  /// Creates an unmodifiable projection of the given [source] event.
  ///
  /// This constructor is used internally by [TissueEvent.unmodifiable].
  UnmodifiableTissueEventBase(TissueEventBase<E> super.source) : _source = source;

  /// Returns a defensive shell that hides the event's payload.
  ///
  /// Even though this event is already unmodifiable, the shell adds an
  /// extra layer of protection by forcing the receiver to authenticate
  /// before revealing the payload.
  ///
  /// ### Returns:
  /// A [TissueEventShell] that gates access to the event.
  @override
  TissueEventShell<E> get shell => TissueEventShell<E>._(this);

  /// Adds a step to the trace, returning a **new** evolved event.
  ///
  /// This does **not** mutate the current unmodifiable event – it creates
  /// a new event that is a child of the source event.
  ///
  /// ### When to use
  /// You want to add a processing step to the event, but you need to keep
  /// the original unmodifiable view intact.
  ///
  /// ### Example
  /// ```dart
  /// final readOnly = event.unmodifiable;
  /// final newEvent = readOnly.withStep('logged'); // new event
  /// ```
  ///
  /// ### Parameters:
  /// - [step]: The step description to add to the trace.
  ///
  /// ### Returns:
  /// A new [TissueEvent] with the updated trace.
  @override
  TissueEventBase<E> withStep(String step) {
    return _source.withStep(step);
  }

  /// The [Tissue] that originally emitted the event.
  ///
  /// ### Returns:
  /// The [Tissue] that caused this event, or `null` if unknown.
  @override
  Tissue? get source => super.source as Tissue?;

  /// The primordial ancestor of this event lineage.
  ///
  /// ### Returns:
  /// The root event in the causal chain.
  @override
  TissueEventBase<E> get root => super.root as TissueEventBase<E>;

  /// Creates a new event that is a child of the source event.
  ///
  /// This does **not** mutate the current unmodifiable event.
  ///
  /// ### Parameters:
  /// - [pulse]: Optional pulse to associate with the new event.
  /// - [step]: Optional step description to add to the trace.
  /// - [context]: Optional context override for the new event.
  ///
  /// ### Returns:
  /// A new [EvolvedTissueEvent] linked to the source event as its parent.
  @override
  TissueEvent evolve({Pulse? pulse, String? step, covariant PulseContext? context}) {
    return _source.evolve(pulse: pulse, step: step, context: context);
  }

  /// Returns this projection – it's already unmodifiable.
  ///
  /// ### Returns:
  /// This same unmodifiable event.
  @override
  TissueEventBase<E> get unmodifiable => this;

  /// Combines this event with another to create a [CollectiveTissueEvent].
  ///
  /// The resulting collective will contain this unmodifiable event as one of
  /// its members.
  ///
  /// ### Parameters:
  /// - [other]: The event to combine with this one.
  ///
  /// ### Returns:
  /// A [CollectiveTissueEvent] containing both events.
  @override
  CollectiveTissueEvent operator +(covariant TissueEvent other) {
    return _source + other;
  }

  /// The immediate parent in the causal chain (unmodifiable projection).
  ///
  /// ### Returns:
  /// The parent event, or `null` if this is the root.
  @override
  TissueEventBase<E>? get _parent => _source._parent;

  /// The internal record backing this event.
  @override
  get _record => _source._record;

  /// The branch completion counter.
  ///
  /// ### Returns:
  /// A [Box<int>] containing the remaining branch count, or `null` if this
  /// is an atomic (non‑composite) event.
  @override
  Box<int>? get _branches => _source._branches;

  // ───── Internal Callback Forwarding ─────

  @override
  void _complete() {
    _source._complete();
  }

  @override
  void _fail(Object error, {StackTrace? stackTrace}) {
    _source._fail(error, stackTrace: stackTrace);
  }

  @override
  void _progress(Cell cell, {String? message}) {
    _source._progress(cell, message: message);
  }

  @override
  void Function(TissueEvent<dynamic> event)? get _onComplete {
    return _source._onComplete;
  }

  @override
  void Function(TissueEvent<dynamic> event, Object error, {StackTrace? stackTrace})? get _onError {
    return _source._onError;
  }

  @override
  void Function(TissueEvent event, Cell cell, {String? message})? get _onProgress {
    return _source._onProgress;
  }
}

/* ... (commented out code preserved) ... */

/// Groups the elements of an [Iterable] into a [Map] based on a specified key
/// selection function.
///
/// [groupBy] is a structural utility used to organise a flat collection into
/// categories or "buckets." It is particularly useful for organising search
/// results, categorising entities by type, or grouping model fields by their
/// metadata within the reactive ecosystem.
///
/// ### When to use
/// - You have a flat list of elements and need to organise them into
///   categories (e.g., tasks by status, products by category).
/// - You are building a UI that displays grouped data (e.g., a sectioned list).
/// - You want to perform an aggregation or summary by group (e.g., count items
///   per group).
/// - You are preparing data for a [TissueMap] or a [TissueList] where the
///   grouping key becomes the key of a map.
///
/// You call [groupBy] when you have a list of items and you want to partition
/// them by some common property – for example, grouping a list of tasks by their
/// priority, or grouping a list of users by their role.
///
/// This is a pure, synchronous utility – it does not interact with the reactive
/// graph directly. It's often used in combination with [Tissue] collections to
/// prepare data for display or further processing.
///
/// ### How it works
/// - It iterates through every element in the [values] collection.
/// - For each element, it calls the [key] function to determine which group
///   it belongs to.
/// - It maintains a [Map] where each key points to a [List] of elements that
///   share that key.
/// - If a key is encountered for the first time, a new empty list is created
///   for that bucket.
/// - The order of elements within each group preserves the original iteration
///   order (insertion order).
///
/// ### Non‑obvious
/// - The function returns a **new** [Map] – the original iterable is not
///   modified.
/// - The keys are determined by the [key] function **at the time of grouping**.
///   If the elements are mutable and change later, the grouping is not updated
///   automatically – you would need to re‑run [groupBy].
/// - The values in the resulting map are **new lists** – they are not the same
///   lists as the original iterable. Modifying them does not affect the source.
/// - The function is **lazy** in the sense that it only iterates over the
///   [values] once, but it eagerly collects all elements into the map.
/// - If the [key] function returns `null` for some elements, they are grouped
///   under the key `null` (since Dart maps allow null keys).
///
/// ### Example: Grouping tasks by priority
/// ```dart
/// final tasks = [
///   Task('Buy milk', priority: 'high'),
///   Task('Walk dog', priority: 'low'),
///   Task('Write report', priority: 'high'),
/// ];
///
/// final grouped = groupBy(tasks, (task) => task.priority);
/// // grouped = {
/// //   'high': [Task('Buy milk'), Task('Write report')],
/// //   'low': [Task('Walk dog')],
/// // }
/// ```
///
/// ### Example: Grouping products by category
/// ```dart
/// final products = [
///   Product('Laptop', category: 'Electronics'),
///   Product('Apple', category: 'Food'),
///   Product('Phone', category: 'Electronics'),
/// ];
///
/// final byCategory = groupBy(products, (p) => p.category);
/// // byCategory['Electronics'] contains laptop and phone
/// ```
///
/// ### Example: Using with reactive collections
/// ```dart
/// final tasksList = TissueList<Task>();
/// // ... populate tasksList
/// final grouped = groupBy(tasksList.toList(), (task) => task.priority);
/// // Use the grouped map to populate a sectioned UI list
/// ```
///
/// ### Type Parameters:
/// * [S]: The type of the elements in the source collection.
/// * [T]: The type of the key used to categorise the elements.
///
/// ### Parameters:
/// - [values]: The source [Iterable] containing the elements to be grouped.
/// - [key]: A mapping function that takes an element of type [S] and returns
///   a key of type [T] representing its group.
///
/// ### Returns:
/// A [Map<T, List<S>>] where each entry represents a group of elements
/// sharing the same key.
Map<T, List<S>> groupBy<S, T>(Iterable<S> values, T Function(S) key) {
  var map = <T, List<S>>{};
  for (var element in values) {
    (map[key(element)] ??= []).add(element);
  }
  return map;
}