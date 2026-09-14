// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

/// A [TissuePulse] that has been derived from a previous event, preserving
/// its full causal lineage — the parent‑child chain that explains how the
/// signal evolved.
///
/// ### When to use
/// - Tracing how a change propagated through your reactive graph.
/// - Building explainable audit trails.
/// - Implementing undo/redo or time‑travel debugging.
/// - Understanding why a value changed (the "chain of custody").
///
/// You never create this directly. It's returned by [evolve] or [withStep]
/// when you call them on any [TissuePulse]. The framework uses it to record
/// every transformation step a signal goes through, which is invaluable for
/// debugging, auditing, and explaining AI‑driven decisions.
///
/// ### How it works
/// - Each evolved event links back to its immediate [parent] – the event it
///   was derived from.
/// - The [trace] (inherited from [Pulse]) accumulates all step names from the
///   entire chain.
/// - The [root] always points to the very first event in the lineage.
/// - The payload is inherited from the root – evolved events don't duplicate
///   data, they just add a new layer of metadata.
///
/// ### Non‑obvious
/// - An evolved event is **not** a batch – it's a single event with a history.
///   For batching multiple independent events, use [CollectiveTissuePulse].
/// - The [parent] is never `null` for an evolved event – the root is the only
///   one without a parent.
/// - When you call [evolve] again, you get a new [EvolvedTissuePulse] that
///   links back to the previous one, building a chain.
/// - The event itself is still immutable – evolution creates a new instance.
///
/// ### Example: tracing a value change
/// ```dart
/// final evolved = originalEvent
///     .withStep('validation')
///     .withStep('transformation')
///     .withStep('persistence');
///
/// print(evolved.trace); // ['validation', 'transformation', 'persistence']
/// print(evolved.parent); // the event after 'transformation'
/// print(evolved.root);   // the original ElementAddedEvent
/// ```
///
/// ### Type Parameters:
/// * [E] – The type of the event's payload (the data that changed).
///
/// See also:
/// * [TissuePulse] – the base interface for all collection events.
/// * [CollectiveTissuePulse] – a batch of multiple events, not a chain.
abstract interface class EvolvedTissuePulse<E>
    implements TissuePulse<E>, EvolvedPulse<E> {
  /// The preceding structural signal that triggered this evolved event.
  ///
  /// ### When to use
  /// Use this getter when you need to know the original reason for a
  /// structural change, such as identifying the first element added in
  /// a multi-step update.
  ///
  /// Access this property on any [EvolvedTissuePulse] to inspect its history.
  ///
  /// ### How it works
  /// - It returns the immediate ancestor in the causal chain.
  /// - The returned object is a [TissuePulse], preserving the structural
  ///   context of the collection.
  ///
  /// ### Non‑obvious
  /// - This property creates a "linked list" of history, allowing you
  ///   to traverse back to the root of the interaction.
  /// - Evolution ensures that even though the event is new, its
  ///   origin is never lost.
  ///
  /// ### Example
  /// ```dart
  /// final previous = evolved.parent;
  /// print('Previous event type: ${previous.runtimeType}');
  /// ```
  @override
  TissuePulse<E> get parent;

  /// Merges this evolved event with another to form a batch transaction.
  ///
  /// ### When to use
  /// Use this to combine refined structural changes into a single collective
  /// pulse for batch processing.
  ///
  /// Use the `+` operator between this instance and another [TissuePulse].
  ///
  /// ### How it works
  /// - It creates a new [CollectiveTissuePulse] containing both signals.
  /// - It preserves the evolutionary history of the evolved event within
  ///   the new batch.
  /// - It ensures that the resulting collection of pulses is treated as a
  ///   unified atomic update.
  ///
  /// ### Non‑obvious
  /// - If the [other] event is already a [CollectiveTissuePulse], this event
  ///   is appended to that collection.
  /// - The operation is non-destructive; it returns a new signal instance
  ///   rather than modifying the existing ones.
  ///
  /// ### Example
  /// ```dart
  /// final batch = evolvedEvent + nextEvent;
  /// ```
  CollectiveTissuePulse operator +(covariant TissuePulse other);
}

/// A batch of multiple independent [TissuePulse]s that travel together as a
/// single atomic wave.
///
/// ### When to use
/// - You have multiple related changes that must be applied atomically.
/// - You want to reduce overhead by combining several small events into one.
/// - You need to iterate over a collection of events as a single entity.
/// - You want to apply common metadata (context, type, priority) to all of them.
///
/// You never create this directly – it's returned by [Pulse.batch] (or
/// `TissueEvent.batch`) or the `+` operator when combining events. Use it when
/// you need to process several changes as one unit.
///
/// ### How it works
/// - The collective holds an iterable of [TissuePulse]s as its [payload].
/// - It implements [Iterable], so you can loop over it to access each event.
/// - The collective is processed as a single unit – all sub‑events travel
///   together through the reactive graph.
/// - Each sub‑event retains its own identity, causal trace, and parent chain.
/// - The collective's own metadata (type, context, source) can be overridden
///   via the `.governed` constructor.
///
/// ### Non‑obvious
/// - A collective is **not** a chain – it does **not** create a causal
///   relationship between its members. Each event's `parent` remains unchanged.
/// - The collective's [root] is itself (it's a root collective), but each
///   sub‑event's [root] remains its own root.
/// - The `onComplete` and `onError` callbacks are taken from the **first**
///   event in the iterable (or overridden). They are **not** applied to each
///   individual event – they fire once for the whole batch.
/// - If the iterable is empty, the collective still exists (with `null` payload
///   and `isComposite` `true`).
/// - The `+` operator on a collective creates a new collective that combines
///   both batches (flattened).
/// - When you [evolve] a collective, it transforms into an [EvolvedTissuePulse]
///   (a chain), not another collective – because evolution adds a causal step.
///
/// ### Example: Batching two events
/// ```dart
/// final added = ElementAddedEvent<int>(payload: 1);
/// final removed = ElementRemovedEvent<int>(payload: 2);
/// final batch = CollectiveTissueEvent.from([added, removed]);
///
/// // Access the events
/// for (final event in batch) {
///   print(event.payload);
/// }
///
/// // Or use the + operator
/// final combined = added + removed; // also a CollectiveTissueEvent
/// ```
///
/// ### Example: Overriding metadata
/// ```dart
/// final batch = CollectiveTissueEvent.governed(
///   [added, removed],
///   type: 'bulk_operation',
///   priority: 80,
///   context: PulseContext.userAction(actor: 'admin'),
/// );
/// // All sub‑events will inherit the collective's type/priority/context
/// // unless they override it themselves.
/// ```
///
/// ### Type Parameters:
/// * [E] – The type of the payload – for a collective, this is the type of
///   the **first** event's payload (used for backward compatibility).
///
/// See also:
/// * [TissuePulse] – a single change event.
/// * [EvolvedTissuePulse] – a single event with a history (chain).
/// * [TissuePulse.batch] – the factory that creates these.
abstract interface class CollectiveTissuePulse<E>
    implements TissuePulse<Iterable<Pulse<E>>>, CollectivePulse<E> {
  /// Creates a collective from an iterable of events.
  ///
  /// This is the simplest way to batch events. The metadata (context, type,
  /// source, priority) is taken from the **first** event in the iterable.
  /// If you need to override that metadata, use the [governed] constructor.
  ///
  /// ### When to use
  /// - You already have a list of events and want to send them together.
  /// - You're happy with the metadata from the first event.
  ///
  /// ### How it works
  /// The factory takes an iterable of [TissuePulse]s and wraps them into a
  /// single collective. The collective's `payload` is the iterable itself.
  ///
  /// ### Example
  /// ```dart
  /// final events = [addEvent, removeEvent, updateEvent];
  /// final batch = CollectiveTissueEvent.from(events);
  /// ```
  factory CollectiveTissuePulse.from(Iterable<TissuePulse<E>> events) =
      _CollectiveTissueEvent<E>;

  /// Creates a collective with explicit metadata overrides.
  ///
  /// Use this when you need to set a specific [type], [context], [priority],
  /// or callbacks for the entire batch, regardless of the first event's values.
  ///
  /// ### When to use
  /// - You need to apply a uniform context (e.g., same actor, reason) to all
  ///   events in the batch.
  /// - You want to set a custom priority for the batch.
  /// - You need to attach completion/error callbacks to the whole batch.
  ///
  /// ### How it works
  /// All named parameters are optional – if omitted, the values from the first
  /// event are used. The [scrutinize] parameter allows you to provide a custom
  /// authentication challenge for the batch.
  ///
  /// ### Example
  /// ```dart
  /// final batch = CollectiveTissueEvent.governed(
  ///   [addEvent, removeEvent],
  ///   type: 'admin_batch',
  ///   context: PulseContext(actor: 'admin'),
  ///   priority: 90,
  ///   onComplete: (pulse) => print('Batch completed'),
  /// );
  /// ```
  factory CollectiveTissuePulse.governed(
    Iterable<TissuePulse<E>> events, {
    PulseEphemeralPolicy? policy,
    PulseContext? context,
    String? type,
    Tissue? source,
    String? step,
    int? priority,
    void Function(TissuePulse event)? onComplete,
    void Function(TissuePulse event, Object error, {StackTrace? stackTrace})?
        onError,
    void Function(TissuePulse event, Cell cell, {String? message})? onProgress,
    FutureOr<TissuePulse?> Function(TissueReceptor receptor)? scrutinize,
  }) = _CollectiveTissueEvent<E>;

  /// The collection of events bundled in this collective.
  ///
  /// This is the entire iterable provided to the factory. It is immutable.
  ///
  /// ### When to use
  /// - Access the individual events.
  /// - Iterate over them manually.
  /// - Check the size of the batch.
  ///
  /// ### Example
  /// ```dart
  /// final events = batch.payload;
  /// print('Batch size: ${events.length}');
  /// ```
  @override
  Iterable<TissuePulse<E>> get payload;

  /// Combines this collective with another event (or collective) into a new
  /// collective that contains all events from both.
  ///
  /// This is the same as using the `+` operator on any two [TissuePulse]s.
  /// The resulting collective flattens any nested collectives – you get a
  /// single, flat list of all events.
  ///
  /// ### When to use
  /// - You have two batches that need to be processed together.
  /// - You want to append or prepend an event to an existing batch.
  ///
  /// ### How it works
  /// The operator creates a new [CollectiveTissuePulse] that contains the
  /// events from `this` followed by the events from [other]. If [other] is
  /// itself a collective, its events are flattened into the new one.
  ///
  /// ### Example
  /// ```dart
  /// final batch1 = CollectiveTissueEvent.from([a, b]);
  /// final batch2 = CollectiveTissueEvent.from([c, d]);
  /// final combined = batch1 + batch2; // contains a, b, c, d
  /// ```
  CollectiveTissuePulse operator +(covariant TissuePulse other);
}

/// A defensive, read‑only shell that wraps a [TissuePulse] and forces any
/// receiver to authenticate itself before the event's payload is revealed.
///
/// ### When to use
/// - Passing an event across security boundaries (e.g., to a plugin, a
///   sandbox, or an external callback).
/// - Implementing a zero‑trust architecture where every access must be
///   challenged.
/// - Protecting sensitive payloads from being inspected by unauthorised code.
///
/// You never create this directly. It's returned by the `shell` getter on any
/// [TissuePulse]. Use it when you need to send an event to an untrusted
/// component – the shell ensures that the component must prove its identity
/// and clearance before accessing the data.
///
/// ### How it works
/// - The shell hides the actual event's payload and most metadata.
/// - Any attempt to read the payload through normal getters returns `null`.
/// - To unlock the event, the receiver must call `scrutinize(receptor, ...)`,
///   passing its own [TissueReceptor] as evidence.
/// - If the receptor is authorised, the shell returns the underlying event.
/// - If not, it returns `null` – the signal is neutralised.
///
/// ### Non‑obvious
/// - The shell is terminal – you cannot [evolve] or [withStep] it.
/// - The shell is itself an [Iterable] that yields only itself.
/// - The shell is the primary mechanism for **reciprocal handshake** –
///   both the pulse and the receptor validate each other.
///
/// ### Example
/// ```dart
/// final event = ElementAddedEvent<int>(payload: 42);
/// final shell = event.shell;
///
/// // In the receiver (e.g., a receptor):
/// final unlocked = shell.scrutinize(thisReceptor);
/// if (unlocked != null) {
///   // Process the event
/// }
/// ```
///
/// ### Type Parameters:
/// * [E] – The type of the event's payload.
class TissueEventShell<E> extends PulseShell<E, TissueReceptor>
    implements TissuePulse<E> {
  const TissueEventShell._(TissueEventBase<E> super.kernal) : super();

  @override
  Iterator<TissuePulse> get iterator => [this].iterator;

  /// Attempts to merge this shell with another signal, which is **not supported**.
  ///
  /// ### Rationale: Security Termination
  /// A [TissueEventShell] is a defensive, zero-trust proxy. Allowing the `+`
  /// operator would enable the creation of a [CollectiveTissuePulse] where
  /// the shell is bundled with other, potentially unprotected signals.
  ///
  /// To prevent metadata leakage and to ensure the **reciprocal handshake**
  /// remains focused on a single causal origin, shells are considered terminal
  /// in the composition chain.
  ///
  /// ### How to combine signals with a shell
  /// If you need to batch a shielded event, you must first:
  /// 1.  [scrutinize] the shell using a valid [TissueReceptor] to unlock it.
  /// 2.  Perform the addition on the resulting [TissuePulse].
  ///
  /// ### Errors
  /// Throws an [UnsupportedError] if invoked, as composition violates the
  /// encapsulation contract of the shell.
  @override
  TissuePulse operator +(covariant Pulse other) {
    throw UnsupportedError('PulseShell not supported for addition.');
  }

  @override
  TissueEventShell<E> get shell => this;

  @override
  TissuePulse evolve(
      {Pulse? pulse, String? step, covariant PulseContext? context}) {
    throw UnsupportedError('PulseShell cannot be evolved.');
  }

  @override
  TissuePulse<E> get root => this;

  @override
  Tissue? get source => super.source as Tissue?;

  @override
  TissuePulse<E> get unmodifiable => this;

  @override
  dynamic scrutinize(
      covariant TissueReceptor receptor, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]) {
    return super.scrutinize(receptor, positionalArguments, namedArguments);
  }

  @override
  TissuePulse<E> withStep(String step) {
    throw UnsupportedError('PulseShell cannot be evolved.');
  }
}

/// A structural signal emitted by a [Tissue] when its internal state changes.
///
/// ### When to use
/// - Reacting to changes in a collection: update a UI, trigger a side effect,
///   or log the change.
/// - Implementing reactive data flows where downstream logic depends on
///   what changed.
/// - Auditing: recording every mutation for compliance or debugging.
///
/// You don't create these events directly – the framework emits them
/// automatically when you mutate a [Tissue] (add, remove, clear, etc.).
/// You receive them via the `listen` method on any tissue.
///
/// ### How it works
/// - Each event is emitted **after** the mutation is applied and validated.
/// - The event carries the [payload] (the changed value(s)), the [source]
///   tissue, and a full causal [trace].
/// - The event is immutable – it represents a fact that has already occurred.
/// - You can [evolve] the event to add a step to its trace or change its context.
///
/// ### Non‑obvious
/// - The event is a [Pulse] – it participates in the same reactive propagation
///   system as any other signal. It can be evolved, batched, and observed.
/// - The event is emitted **after** the mutation, not before. If you need to
///   capture the before state, the event's [ElementUpdatedRecord] or similar
///   payload includes it.
/// - For batch operations (addAll, removeAll), the payload may be an iterable
///   of elements, not a single one.
/// - The event is not emitted for initial population of the tissue – only for
///   mutations that happen after creation.
/// - `null` values are valid payloads – they represent the removal or clearing
///   of a value.
///
/// ### Example: Listening to changes
/// ```dart
/// final list = TissueList<int>([1, 2, 3]);
/// list.listen((event) {
///   if (event is ElementAddedEvent<int>) {
///     print('Added: ${event.payload}');
///   }
///   if (event is ElementRemovedEvent<int>) {
///     print('Removed: ${event.payload}');
///   }
/// });
/// list.add(4); // prints "Added: 4"
/// list.remove(2); // prints "Removed: 2"
/// ```
///
/// ### Type Parameters:
/// * [E] – The type of the event's payload (the element or value that changed).
///
/// See also:
/// - [ElementAdded] – for when elements are added.
/// - [ElementRemoved] – for when elements are removed.
/// - [ElementUpdated] – for when a scalar value changes.
/// - `Tissue.listen` – the method that delivers these events.
abstract interface class TissuePulse<E> implements Pulse<E> {
  /// Batches multiple events into a single [CollectiveTissuePulse].
  ///
  /// ### When to use
  /// Use this when you have a collection of events that should be processed
  /// together as one atomic unit.
  ///
  /// ### How it works
  /// - The events are bundled into a [CollectiveTissuePulse].
  /// - The resulting event is a composite that can be iterated over.
  ///
  /// ### Example
  /// ```dart
  /// final batch = TissueEvent.batch([addEvent, removeEvent]);
  /// ```
  static TissuePulse batch<E>(
    Iterable<TissuePulse<E>> events, {
    PulseEphemeralPolicy? policy,
    PulseContext? context,
    String? type,
    Tissue? source,
    String? step,
    int? priority,
    void Function(TissuePulse event)? onComplete,
    void Function(TissuePulse event, Object error, {StackTrace? stackTrace})?
        onError,
    void Function(TissuePulse event, Cell cell, {String? message})? onProgress,
    FutureOr<TissuePulse?> Function(TissueReceptor receptor)? scrutinize,
  }) =>
      _CollectiveTissueEvent<E>(events);

  /// Challenges a receptor to prove its authority before revealing the event.
  ///
  /// ### When to use
  /// You rarely call this directly – it's used internally by the framework
  /// during the reciprocal handshake.
  ///
  /// ### How it works
  /// - The event (via its shell) validates the receptor's identity and clearance.
  /// - If authorised, the event is unlocked and can be processed.
  /// - If not, `null` is returned – the signal is neutralised.
  ///
  /// ### Returns:
  /// The event itself if authorised; `null` otherwise.
  @override
  dynamic scrutinize(covariant Receptor receptor, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]);

  /// Returns a defensive proxy of this event for safe distribution.
  ///
  /// ### When to use
  /// Use this when you need to send an event to untrusted code – the shell
  /// hides the payload until the receiver authenticates.
  ///
  /// ### Returns:
  /// A [TissueEventShell] that gates access to the event.
  @override
  TissueEventShell<E> get shell;

  /// Appends a step to the event's causal trace.
  ///
  /// ### When to use
  /// Use this to document a significant milestone in the event's journey
  /// through the reactive graph.
  ///
  /// ### Returns:
  /// A new [TissuePulse] with the updated trace.
  @override
  TissuePulse<E> withStep(String step);

  /// The tissue that emitted this event.
  ///
  /// ### When to use
  /// Use this to identify which collection changed.
  ///
  /// ### Returns:
  /// The [Tissue] that caused this event, or `null` if the source is unknown.
  @override
  Tissue? get source;

  /// The primordial ancestor of this event's causal lineage.
  ///
  /// ### When to use
  /// Use this to trace an event back to its original source.
  ///
  /// ### Returns:
  /// The root event in the causal chain.
  @override
  TissuePulse<E> get root;

  /// Creates a new event that links back to this one as its parent.
  ///
  /// ### When to use
  /// Use this when you need to add a causal step to an event without changing
  /// its payload.
  ///
  /// ### Returns:
  /// An [EvolvedTissuePulse] that preserves the full lineage.
  @override
  TissuePulse evolve(
      {Pulse? pulse, String? step, covariant PulseContext? context});

  /// Returns a read‑only projection of this event.
  ///
  /// ### When to use
  /// Use this when you need to share an event with code that should only
  /// read it, never derive new events from it.
  ///
  /// ### Returns:
  /// An [UnmodifiableTissuePulse] that blocks evolution.
  @override
  TissuePulse<E> get unmodifiable;

  /// Combines this event with another into a [CollectiveTissuePulse].
  ///
  /// ### When to use
  /// Use this to batch two or more events together for atomic processing.
  ///
  /// ### Returns:
  /// A [CollectiveTissuePulse] containing both events.
  @override
  TissuePulse operator +(covariant TissuePulse other);
}

/// A read‑only, immutable projection of a [TissuePulse] that guarantees no
/// further evolution or mutation.
///
/// ### When to use
/// - Logging or serialising an event for auditing.
/// - Passing an event to a UI component that should only display data.
/// - Sending an event to a sandboxed or untrusted environment.
///
/// You never create this directly. It's returned by the `unmodifiable` getter
/// on any [TissuePulse]. Use it when you need to share an event with code that
/// should only read its data but never derive new events from it.
///
/// ### How it works
/// - The unmodifiable projection wraps the source event and delegates all
///   read operations to it.
/// - Any [Cell] in the payload is automatically projected as its `.unmodifiable`
///   deputy when accessed.
/// - The causal chain (`parent`, [root], [source]) is also projected as
///   unmodifiable.
/// - Attempts to call [evolve] or [withStep] throw an [UnsupportedError].
/// - The projection is **live** – if the source event were mutable (it isn't),
///   the projection would reflect changes, but events are immutable.
///
/// ### Non‑obvious
/// - This is a zero‑copy projection – the underlying data is not duplicated.
/// - It is recursive: `parent` and [root] are also unmodifiable projections.
/// - For composite events (collectives), iteration yields unmodifiable
///   projections of each sub‑event.
/// - The unmodifiable view is still iterable – you can loop over it.
///
/// ### Example
/// ```dart
/// final event = ElementAddedEvent<int>(payload: 42);
/// final readOnly = event.unmodifiable;
///
/// // readOnly.evolve(step: 'new'); // throws UnsupportedError
/// print(readOnly.payload); // 42 (safe to read)
/// ```
///
/// ### Type Parameters:
/// * [E] – The type of the event's payload.
abstract interface class UnmodifiableTissuePulse<E>
    implements TissuePulse<E>, UnmodifiablePulse<E> {
  /// Creates an unmodifiable projection of an event.
  ///
  /// ### When to use
  /// You rarely call this directly – use [TissuePulse.unmodifiable] instead.
  ///
  /// ### Parameters:
  /// - [source]: The event to project.
  ///
  /// ### Returns:
  /// An unmodifiable view of the event.
  factory UnmodifiableTissuePulse(TissuePulse<E> source) =
      _UnmodifiableTissueEvent<E>;

  /// Combines this event with another into a collective.
  ///
  /// ### When to use
  /// Batch this event with another for atomic processing.
  ///
  /// ### Returns:
  /// A [CollectiveTissuePulse] containing both events.
  TissuePulse operator +(covariant TissuePulse other);
}

/// A specialised [TissuePulse] signifying the addition of new elements
/// to a reactive collection.
///
/// In the reactive framework, the [ElementAdded] represents a
/// **Structural Expansion**. It is dispatched by tissue nodes (such as
/// lists, sets, or queues) whenever the internal population increases, allowing
/// downstream [Receptor]s (Transformation Pipelines) to react specifically to
/// the insertion of new entries.
///
/// ### When to use
/// Listen for this event when you need to react to insertions – e.g., to
/// animate a new row in a UI list, to update a summary count, or to validate
/// that the addition complies with business rules.
///
/// ### How it works
/// - The event is emitted after the element has been successfully added and
///   validated by the collection's [TestTissue].
/// - The [payload] is the added element (or an iterable of elements if the
///   operation was a batch add like `addAll`).
/// - The event carries the full causal trace, including the [source] tissue
///   and the [timestamp].
///
/// ### Non‑obvious
/// - For batch operations (e.g., `addAll`), the payload is an `Iterable<E>`,
///   not a single element. The event's [isComposite] may be `true`, and you
///   can iterate over it to process each element individually.
/// - The event does **not** contain the index at which the element was added.
///   If you need positional information, consider using a [TissueList] and
///   reading the current index from the list after the event.
///
/// ### Example
/// ```dart
/// final list = TissueList<int>();
/// final observer = Cell.observe(
///   bind: list,
///   onPulse: (pulse, {user}) {
///     if (pulse is ElementAddedEvent<int>) {
///       print('Added: ${pulse.payload}');
///     }
///   },
/// );
/// list.add(42); // prints "Added: 42"
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of the element being added.
class ElementAdded<E> extends _TissuePulse<E> {
  ElementAdded._({
    super.policy,
    super.context,
    super.payload,
    super.timestamp,
    super.source,
    super.step,
    super.onComplete,
    super.onError,
    super.onProgress,
    super.pulse,
    super.parent,
  }) : super();
}

/// A specialised [TissuePulse] signifying the removal or disposal of an
/// element from a reactive collection.
///
/// In the reactive framework, [ElementRemoved] represents a
/// **Structural Contraction**. It is dispatched by tissue nodes (such as
/// lists, sets, or queues) whenever a member is removed, allowing downstream
/// [Receptor]s to react specifically to the departure or exclusion of elements
/// from the aggregate state.
///
/// ### When to use
/// Listen for this event when you need to react to deletions – e.g., to
/// remove a UI row, to update a summary count, or to clean up external
/// resources associated with the removed element.
///
/// ### How it works
/// - The event is emitted after the element has been successfully removed and
///   any necessary cleanup (like unlinking synapses) has been performed.
/// - The [payload] is the removed element (or an iterable of elements if the
///   operation was a batch removal like `removeAll` or `clear`).
/// - The event carries the full causal trace.
///
/// ### Non‑obvious
/// - For batch removals, the payload is an `Iterable<E>`. You can iterate over
///   it to process each removed element.
/// - The event does **not** contain the index from which the element was removed
///   (for lists). If you need that, capture the state before removal or use
///   a custom listener.
/// - The removed element is still the original object; it has not been modified
///   by the removal operation.
///
/// ### Example
/// ```dart
/// final list = TissueList<int>([1, 2, 3]);
/// final observer = Cell.observe(
///   bind: list,
///   onPulse: (pulse, {user}) {
///     if (pulse is ElementRemovedEvent<int>) {
///       print('Removed: ${pulse.payload}');
///     }
///   },
/// );
/// list.removeAt(1); // prints "Removed: 2"
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of the element being removed.
class ElementRemoved<E> extends _TissuePulse<E> {
  ElementRemoved._({
    super.policy,
    super.context,
    super.payload,
    super.timestamp,
    super.source,
    super.step,
    super.onComplete,
    super.onError,
    super.onProgress,
    super.pulse,
    super.parent,
  }) : super();
}

/// A record that captures a before‑and‑after snapshot of a reactive value
/// change, delivered as the payload of a [ElementUpdated].
///
/// ### When to use
/// - Reacting to a value change in a UI: update a label, animate a transition,
///   or log the state evolution.
/// - Implementing undo/redo: capture the before value and the after value.
/// - Auditing: record who changed what and when (the event itself carries
///   provenance).
/// - Conditional logic: compare the before and after to decide what to do next.
///
/// You never create this record directly. It's constructed automatically by
/// the framework and delivered to you as the payload of a [ElementUpdated]
/// when you listen to a [TissueValue] or a [ValueCell]. Use it to see exactly
/// what changed – the old value (`before`) and the new value (`after`).
///
/// ### How it works
/// This is a Dart **record** (not a class), so it's lightweight and immutable.
/// The record has three fields:
/// - `value`: The [TissueValue] that changed – you can use this to reference
///   the cell that emitted the event.
/// - `before`: The value **before** the change. May be `null` if the cell
///   was uninitialised or if it was set to `null`.
/// - `after`: The value **after** the change. May be `null` if the cell
///   was cleared or set to `null`.
///
/// The record is typically destructured in the event handler:
/// ```dart
/// final event = ValueChangedEvent<int, TissueValue<int>>(...);
/// final (cell, :before, :after) = event.payload!;
/// print('$cell changed from $before to $after');
/// ```
///
/// ### Non‑obvious
/// - **Deep immutability**: If the value (before or after) is itself a [Cell],
///   and the event was emitted by an unmodifiable view, the record will
///   contain the `.unmodifiable` deputy of that cell – not the mutable original.
///   This prevents you from accidentally mutating the source through the event.
/// - **The `value` field is the cell**: It's not the raw value – it's the
///   reactive container that holds the value. This is useful if you need to
///   observe or mutate it later (though in an unmodifiable event, you can't).
/// - **Both `before` and `after` can be `null`**: This is normal – a cell
///   can be uninitialised (`before: null`) or cleared (`after: null`). Always
///   handle `null` gracefully.
/// - **The record is not typed with the cell type**: The second type parameter
///   [E] is the concrete `TissueValue` subtype – you can narrow it to
///   a specific cell class if needed.
/// - **Equality**: Because this is a record, equality is value‑based. Two
///   records with the same `value`, `before`, and `after` are considered equal.
///
/// ### Example: Destructuring in an event handler
/// ```dart
/// final valueCell = TissueValue<int>(0);
/// valueCell.listen((event) {
///   if (event is ValueChangedEvent<int, TissueValue<int>>) {
///     // Destructure the record for easy access
///     final (cell, :before, :after) = event.payload!;
///     print('${cell.runtimeType} changed from $before to $after');
///   }
/// });
///
/// valueCell.value = 42; // prints: "TissueValue<int> changed from 0 to 42"
/// ```
///
/// ### Example: Handling null values
/// ```dart
/// final cell = TissueValue<String>();
/// cell.value = 'Hello'; // before: null, after: 'Hello'
/// cell.value = null;    // before: 'Hello', after: null
/// ```
///
/// ### Type Parameters:
/// * [V] – The type of the value being tracked (e.g., `int`, `String`).
/// * [E] – The concrete [TissueValue] type that holds the value – this is
///   usually `TissueValue<V>` or a custom subtype.
///
/// ### See also:
/// * [ElementUpdated] – the event that carries this record.
/// * [TissueValue] – the reactive cell that emits these events.
/// * [Cell.unmodifiable] – how deep immutability is enforced.
typedef ElementUpdatedRecord<V, E extends TissueValue<V>> = ({
  E value,
  V? before,
  V? after,
});

/// A specialised [TissuePulse] signifying a discrete state transition or value
/// evolution within the reactive framework.
///
/// [ElementUpdated] is the primary architectural signal for communicating
/// **Value‑Based Deltas**. It is dispatched by reactive nodes whenever their
/// internal state evolves, providing downstream [Receptor]s with the
/// high‑fidelity telemetry required to reason about "Before" and "After"
/// state transitions.
///
/// ### When to use
/// - React to changes in a single scalar value – e.g., updating a progress bar,
///   refreshing a label, or invalidating a cache.
/// - Differentiate between an initialisation (before is null) and an update
///   (before is not null).
/// - Track the history of a value for undo/redo functionality.
///
/// You receive this event when listening to a [TissueValue]. It is emitted
/// whenever the value changes (including when set to `null`).
///
/// ### How it works
/// - The event is emitted after the value has been validated and committed.
/// - The [payload] is a [ElementUpdatedRecord] containing the before and after values.
/// - The event carries the full causal trace.
///
/// ### Non‑obvious
/// - The payload is a record, not a single value – you need to destructure it
///   to access the before and after.
/// - If the new value is identical to the old value (by `==`), the event is
///   **not** emitted – the framework deduplicates to avoid unnecessary pulses.
/// - The event is also emitted when the value is set to `null`, so `after` can
///   be `null`.
///
/// ### Example
/// ```dart
/// final valueCell = TissueValue<int>(0);
/// final observer = Cell.observe(
///   bind: valueCell,
///   onPulse: (pulse, {user}) {
///     // Destructure the record payload for easy access
///     if (pulse is ValueChangedEvent<int, TissueValue<int>>) {
///       final (cell, :before, :after) = pulse.payload!;
///       print('Cell $cell changed from $before to $after');
///     }
///   },
/// );
/// valueCell.value = 42; // prints "Cell TissueValue#1 changed from 0 to 42"
/// ```
///
/// ### Type Parameters:
/// * [V]: The type of the value carried by the associated [TissueValue].
/// * [E]: The concrete [TissueValue] implementation.
class ElementUpdated<V, E extends TissueValue<V>>
    extends _TissuePulse<ElementUpdatedRecord<V, E>> {
  ElementUpdated._({
    super.policy,
    super.context,
    super.payload,
    super.timestamp,
    super.source,
    super.step,
    super.onComplete,
    super.onError,
    super.onProgress,
    super.pulse,
    super.parent,
  }) : super();
}
