// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

// ignore_for_file: unused_element
// ignore_for_file: unused_field

/// A concrete implementation of a mutable [Tissue] collection.
///
/// [_Tissue] is the primary workhorse implementation of the [Tissue] interface,
/// providing the full reactive, observable, and thread‑safe collection
/// capabilities. It is instantiated by the public factory methods like
/// `TissueList()`, `TissueSet()`, etc.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// public factory methods on [Tissue] or the concrete subtypes like
/// [TissueList], [TissueSet], etc.
///
/// ### How it works
/// - It extends [UnmodifiableTissueBase] and provides the mutable implementation.
/// - It holds a [TissueNucleus] that defines the collection's behaviour.
/// - It implements `deputy()` to create restricted views.
/// - It provides the `async` getter for non‑blocking operations.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [I]: The internal storage type.
/// * [C]: The concrete tissue interface.
class _Tissue<E, I extends Iterable<E>, C extends Tissue<E>>
    extends UnmodifiableTissueBase<E, I, C> {
  _Tissue(
    Iterable<E> elements, {
    EphemeralPolicy? ephemeralPolicy,
    Cell? bind,
    Context context = Context.system,
    TissueReceptor<E, C> receptor = TissueReceptor.passThrough,
    TestTissue<E, C> testRule = TestTissue.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : this.fromNucleus(
            _TissueNucleus<E, I, C>(
              bind: bind,
              context: context,
              testRule: testRule,
              receptor: receptor,
              synapses: synapses,
              ephemeralPolicy: ephemeralPolicy,
            ),
            elements: elements);

  _Tissue.empty({
    Cell? bind,
    Context context = Context.system,
    TissueReceptor<E, C> receptor = TissueReceptor.passThrough,
    TestTissue<E, C> testRule = TestTissue.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : this.fromNucleus(_TissueNucleus<E, I, C>(
            bind: bind,
            context: context,
            testRule: testRule,
            receptor: receptor,
            synapses: synapses));

  _Tissue.fromNucleus(TissueNucleus<E> nucleus, {super.elements})
      : super(nucleus as TissueNucleusBase<E, I, C>);

  @override
  FutureOr<Tissue<E>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue<E, C> testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) {
    return _TissueDeputy<E, I, C>._(this,
        context: context,
        testRule: testRule,
        ephemeralPolicy: ephemeralPolicy,
        synapses: synapses);
  }

  @override
  TissueModifiableAsync<E, Tissue<E>> get async =>
      TissueModifiableAsync<E, Tissue<E>>(this);

  @override
  Iterable<R> cast<R>() => _nucleus.container.cast<R>();

  @override
  E elementAt(int index) {
    final element = _nucleus.container.elementAt(index);
    // Deep immutability: child cells are projected as their unmodifiable
    // deputies when the view was created with unmodifiableElement: true.
    if (unmodifiableElement && element is Cell) {
      return element.unmodifiable as E;
    }
    return element;
  }

  @override
  E get first => _nucleus.container.first;

  @override
  void forEach(void Function(E element) action) =>
      _nucleus.container.forEach(action);

  @override
  E get last => _nucleus.container.last;

  @override
  Iterable<T> map<T>(T Function(E e) toElement) =>
      _nucleus.container.map(toElement);

  @override
  Tissue<E> get unmodifiable => this;

  @override
  TestTissue<E, C> get validate => _nucleus.testRule;
}

/// A concrete implementation of a deputy (restricted view) of a [Tissue].
///
/// [_TissueDeputy] implements the **Deputy Pattern** for tissues. It shares
/// the same physical storage and lock as the principal but applies different
/// validation rules, context, or lifecycle policies.
///
/// ### When to use
/// This is an internal class. You obtain deputies via the `deputy()` method on
/// any [Tissue] – you never instantiate this directly.
///
/// ### How it works
/// - It extends `_Tissue` and mixes in `Deputy`.
/// - The deputy's [TestTissue] is the composition of the principal's rule and
///   the deputy's additional rule (you can only narrow permissions).
/// - The deputy gets its own [Synapses] registry by default.
/// - The deputy is logically equal to its principal.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [I]: The internal storage type.
/// * [C]: The concrete tissue interface.
class _TissueDeputy<E, I extends Iterable<E>, C extends Tissue<E>>
    extends _Tissue<E, I, C> with Deputy<Tissue<E>> {
  _TissueDeputy._(TissueBase<E, Iterable<E>, C> bind,
      {Context context = Context.system,
      TestTissue<E, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled})
      : super.fromNucleus(TissueNucleus<E>.evolve(bind._nucleus,
            override: _TissueNucleus<E, Iterable<E>, C>.fromRecord((
              local: TissueNucleusBase.mask<E, Iterable<E>, C>(
                bind: bind,
                context: context,
                testRule: bind._nucleus.testRule + testRule,
                synapses: synapses,
                ephemeralPolicy: ephemeralPolicy,
              )
            ))));

  @override
  FutureOr<Tissue<E>> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      TestTissue<E, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _TissueDeputy<E, I, C>._(
        _nucleus.bind as TissueBase<E, Iterable<E>, C>,
        context: context,
        testRule: testRule,
        ephemeralPolicy: ephemeralPolicy,
        synapses: synapses);
  }
}

/// A specialised, highly optimised implementation of a [Tissue] that represents
/// a permanently empty, immutable, and non‑allocating reactive node.
///
/// [TissueNever] serves as the **Null Object** or **Terminal Sentinel** within
/// the `cell_tissue` ecosystem. It is designed to represent a collection that
/// conceptually "never" contains data, providing a type‑safe way to handle empty
/// states without resorting to `null` checks or allocating unnecessary physical
/// buffers.
///
/// ### When to use
/// This class is used internally as a performance optimisation. You might
/// encounter it when you call `Tissue.empty()` with default parameters, or when
/// a `Tissue` is created with no elements and no custom rules. It's safe to
/// use anywhere a `Tissue` is expected.
///
/// You never construct this directly. It is returned by factory methods like
/// `Tissue.empty()` when the framework detects that the configuration is the
/// simplest possible (no bind, no validation, disabled synapses). You can treat
/// it as a regular `Tissue` – it implements all the methods, they just do nothing.
///
/// ### How it works
/// - It is a `const` singleton – all empty, immutable tissues share the same
///   instance, saving memory.
/// - It uses a [TissueNucleusNever] which has no storage, no synapses, and a
///   validation rule that rejects all mutations.
/// - All methods are no‑ops: `deputy()` returns `this`, `unmodifiable` returns
///   `this`, `async` returns a valid but inert async handle.
/// - Iteration yields no elements.
/// - It is thread‑safe and deeply immutable.
///
/// ### Example
/// ```dart
/// final empty = const TissueNever<int>();
/// print(empty.length); // 0
/// print(empty.isEmpty); // true
/// empty.add(1); // no effect, returns false silently
/// ```
class TissueNever extends IterableBase<Never>
    implements TissueBase<Never, Never, Never> {
  /// Creates a constant instance of the empty tissue.
  const TissueNever();

  /// Returns the specialised empty property set.
  ///
  /// This provides a [TissueNucleusBase] configured with an
  /// empty container and no active synapses.
  @override
  TissueNucleusBase<Never, Never, Never> get _nucleus =>
      const TissueNucleusNever();

  /// The empty tissue has no state to synchronise, so it never locks.
  @override
  Lock? get lock => null;

  /// A no‑op implementation of the internal mutation dispatch engine.
  ///
  /// Since the tissue is empty, there are no elements to apply
  /// functions to, and the tissue itself provides no dynamic
  /// callable behaviour.
  @override
  dynamic dispatch(
    Function function, {
    List? positionalArguments,
    Map<Symbol, dynamic>? namedArguments,
  }) {}

  /// The empty tissue has no mutation surface, so every command is
  /// forensically rejected.
  @override
  FutureOr<ApplyOutcome<R>> apply<R>(
    ApplyCommand command, {
    ApplyTransactionScope? tx,
  }) {
    return ApplyRejected<R>(ApplyLedger.receipt(
      cell: this,
      command: command,
      vetted: false,
    ));
  }

  /// Provides an asynchronous wrapper for the empty tissue.
  ///
  /// Returns a [ModifiableAsync] instance pointing to this object,
  /// allowing it to be used in asynchronous pipelines even though
  /// it will never produce values.
  @override
  ModifiableAsync<Cell> get async => ModifiableAsync(this);

  /// Returns itself when a deputy is requested.
  ///
  /// Because the collection is [Never]-typed and empty, any validation
  /// [testRule] applied to it is vacuously true or irrelevant.
  /// Therefore, the most efficient deputy of "nothing" is "nothing".
  @override
  FutureOr<Tissue<Never>> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestTissue<dynamic, Tissue<dynamic>> testRule =
          TestTissue.allowAll,
      EphemeralPolicy<Cell>? ephemeralPolicy,
      Synapses<Pulse<dynamic>, Cell> synapses = Synapses.enabled}) {
    return this;
  }

  /// Returns an empty iterator.
  @override
  Iterator<Never> get iterator => const Iterable<Never>.empty().iterator;

  /// Returns an empty iterable of modifiable functions.
  ///
  /// Part of the [Cell] interface requirement for reflecting
  /// mutation capabilities.
  @override
  Iterable<Function> get modifiable => const Iterable<Function>.empty();

  /// Returns `this` as the tissue is already unmodifiable.
  @override
  Tissue<Never> get unmodifiable => this;

  /// Returns a universal "pass" rule.
  ///
  /// Even though the collection is empty, the validation logic defaults
  /// to [TestTissue.allowAll] to satisfy the interface requirements.
  @override
  TestTissue<dynamic, Tissue<dynamic>> get validate => _nucleus.testRule;

  @override
  Context get context => Context.system;

  @override
  bool get isTerminal => true;

  @override
  bool get isInvalidated => true;

  /// Combines this empty tissue with another tissue.
  ///
  /// Since this tissue is empty, combining it with another tissue returns
  /// the other tissue unchanged. This operator is primarily used for
  /// batching or merging collection events.
  ///
  /// ### When to use
  /// This operator is used internally for event batching. You rarely call
  /// it directly in application code.
  ///
  /// ### How it works
  /// - Returns the [other] tissue as-is, since this tissue has no elements
  ///   to contribute to the combination.
  ///
  /// ### Parameters:
  /// - [other]: The other tissue to combine with this one.
  ///
  /// ### Returns:
  /// The [other] tissue unchanged.
  Tissue operator +(Tissue other) {
    return other;
  }

  @override
  bool get isGoverned => false;
}

/// The foundational abstract base implementation of the [Tissue] interface,
/// providing the core reactive engine and synchronisation domain for all
/// high‑fidelity collections in the `cell` ecosystem.
///
/// [TissueBase] acts as the primary "Nerve Center" for managing groups of
/// elements within the **Conactive** data‑flow graph. It bridges the gap between
/// the high‑level [Tissue] interface and low‑level physical storage
/// ([Container]), orchestrating the entire lifecycle of reactive members—from
/// initial population and structural validation to recursive pulse propagation.
///
/// ### When to use
/// This class is used internally by all tissue implementations. You don't need
/// to interact with it directly. It is the foundation that powers `TissueList`,
/// `TissueSet`, `TissueMap`, `TissueQueue`, and `TissueValue`.
///
/// You never extend this class directly. Instead, you use one of the concrete
/// subtypes like `_Tissue` (for mutable tissues) or `_UnmodifiableTissue` (for
/// read‑only views). This class provides the common plumbing for all of them.
///
/// ### How it works
/// - It holds a [TissueNucleusBase] (the "DNA" of the collection) which defines
///   the rules, context, receptor, and storage strategy.
/// - It mixes in [IterableMixin] to provide standard `Iterable` methods
///   (`map`, `where`, `fold`, etc.) without reimplementing them.
/// - On construction, it initialises the physical container via
///   `_nucleus.container.init(elements)`.
/// - It automatically links any initial elements that are [Cell]s via
///   `_nucleus.synapses.link`. This enables "bubbling" of internal changes.
/// - The `deputy()` method returns a proxy that shares the same data but applies
///   a different validation rule or context.
/// - Equality (`==`) and `hashCode` are based on the container's content, so
///   tissues behave like normal Dart collections in sets and maps.
///
/// ### Type Parameters:
/// * [E]: The type of elements contained within the tissue.
/// * [I]: The internal [Iterable] implementation type (e.g., `List<E>`,
///   `Set<E>`, or `Queue<E>`) used by the physical [Container].
/// * [C]: The specific implementation interface of the [Tissue]
///   (e.g., `TissueList<E>`), used for self‑referential type safety
///   in receptors and deputies.
///
/// See also:
/// - [TissueNucleusBase] – the configuration blueprint for this engine.
/// - [TissueReceptor] – the command engine that drives state evolution.
/// - [TestTissue] – the security authority governing mutations.
abstract class TissueBase<E, I extends Iterable<E>, C extends Tissue<E>>
    extends CellBase with IterableMixin<E> implements Tissue<E> {
  /// The internal configuration and state storage for this tissue.
  ///
  /// This property holds the [TissueNucleusBase] which encapsulates
  /// the underlying [Container], the validation [TestTissue] logic,
  /// and the [Synapses] registry for child cell tracking.
  @override
  final TissueNucleusBase<E, I, C> _nucleus;

  /// The synchronization [Lock] resolved from this tissue's nucleus.
  ///
  /// Overrides [CellBase.lock] because the tissue nucleus shadows the
  /// cell-side private `_nucleus` member; transaction machinery in the core
  /// library acquires this lock through the public accessor.
  @override
  Lock? get lock => _nucleus.lock;

  /// Primary internal constructor for [TissueBase], responsible for
  /// bootstrapping a reactive collection and establishing its initial state
  /// within the **Conactive** data‑flow graph.
  ///
  /// This constructor serves as the foundational "Wiring Engine" for the
  /// entire `cell_tissue` ecosystem. It bridges the gap between a static
  /// configuration blueprint (the [Nucleus]) and live data elements, ensuring
  /// that the tissue enters the graph as a fully integrated, synchronised,
  /// and governed node.
  ///
  /// ### When to use
  /// This is an internal constructor. Subclasses call it with their specific
  /// nucleus type. You never call it directly.
  ///
  /// ### How it works
  /// - It delegates to `super.fromNucleus()` to establish the node's unique
  ///   [Lock], execution [Context], and temporal metadata.
  /// - It triggers the [Container.init] sequence to allocate the physical storage.
  /// - If [elements] are provided, they are committed to the physical container
  ///   within the synchronisation domain.
  /// - It performs a "Deep Scan" of the provided [elements] and automatically
  ///   links every member that implements the [Cell] interface through
  ///   `_nucleus.synapses.link`. This enables **Member‑Level Bubbling**.
  ///
  /// ### Parameters:
  /// - [nucleus]: The [TissueNucleusBase] defining the behavioural
  ///   governance and structural blueprint.
  /// - [elements]: Optional initial [Iterable] of data points to populate the
  ///   collection. These elements are subjected to structural ingestion and
  ///   reactive discovery.
  TissueBase(TissueNucleusBase<E, I, C> super.nucleus, {Iterable<E>? elements})
      : _nucleus = nucleus,
        super.fromNucleus() {
    final container =
        get<Container?>(() => _nucleus.record.local.container, orElse: null);
    if (container != null) {
      _nucleus.container.init(elements);
    }
    if (elements != null) {
      elements
          .whereType<Cell>()
          .forEach((e) => _nucleus.synapses.link(e, downstreamCell: this));
    }
  }

  /// The internal mutation dispatch engine, implemented by each tissue mixin.
  ///
  /// This is the collection-specific routing table that executes whitelisted
  /// mutation functions (`add`, `remove`, `put`, ...) with the tissue's
  /// validation rules. It is invoked by [apply] and by the public mutation
  /// methods of each collection.
  dynamic dispatch(
    Function function, {
    List? positionalArguments,
    Map<Symbol, dynamic>? namedArguments,
  });

  /// Submits a first-class [ApplyCommand] through the tissue dispatch engine.
  ///
  /// Collection mutations (`add`, `remove`, `put`, ...) route through the
  /// specialized dispatch logic of the individual tissue mixins, so the
  /// command model bridges into that engine and wraps its result in an
  /// auditable [ApplyOutcome].
  ///
  /// The dispatch engine reports a rejected mutation with a `null` result,
  /// which this bridge maps to [ApplyRejected]; non-null results map to
  /// [ApplyAccepted].
  @override
  FutureOr<ApplyOutcome<R>> apply<R>(
    ApplyCommand command, {
    ApplyTransactionScope? tx,
  }) {
    if (tx != null) {
      final sequence = tx.enqueueCommand(this, command);
      return ApplyStaged(ApplyLedger.receipt(
        cell: this,
        command: command,
        txSequence: sequence,
        vetted: modifiable.contains(command.function),
      ));
    }

    final result = dispatch(
      command.function,
      positionalArguments: command.arguments.positionalArguments,
      namedArguments: command.arguments.namedArguments,
    );

    final receipt = ApplyLedger.receipt(
      cell: this,
      command: command,
      vetted: modifiable.contains(command.function),
    );

    if (result is Future) {
      return result.then((value) => value == null
          ? ApplyRejected<R>(receipt)
          : ApplyAccepted<R>(value as R, receipt));
    }
    return result == null
        ? ApplyRejected<R>(receipt)
        : ApplyAccepted<R>(result as R, receipt);
  }

  /// Synthesizes a specialised **Mandate Handle** (Deputy) of this collection,
  /// providing a scoped, authoritative interface to the underlying state.
  ///
  /// The [deputy] method is a cornerstone of the framework's governance model.
  /// It implements the **Deputy Pattern**, allowing for the creation of a derived
  /// [Tissue] that remains physically linked to the original (principal) but
  /// operates under a unique layer of validation, execution context, and authority.
  ///
  /// ### When to use
  /// Use this when you need a restricted view of the tissue – e.g., read‑only,
  /// scoped authority, temporary access, or sandboxed simulation.
  ///
  /// ### How it works
  /// - The deputy shares the same physical storage and lock as the source.
  /// - The provided [testRule] is layered on top of the principal's rule
  ///   (you can only narrow permissions, never widen).
  /// - The deputy gets its own [Synapses] registry by default, so it can have
  ///   its own observers.
  /// - If all parameters are left at default, `deputy()` returns `this`.
  ///
  /// ### Parameters:
  /// - [context]: The **DeputyContext** (Authority Tier) defining the
  ///   permissions and identity of this deputy. Defaults to [DeputyContext.system].
  /// - [testRule]: The **Integrity Gate** ([TestTissue]) governing
  ///   permissible actions and membership transitions for this specific handle.
  /// - [ephemeralPolicy]: Optional **Lifecycle Governance** defining the
  ///   temporal or usage‑based limits of this mandate.
  /// - [synapses]: Configuration for the deputy's egress hub. Defaults to
  ///   [Synapses.enabled].
  ///
  /// ### Returns:
  /// A [FutureOr] containing a new [Tissue<E>] instance acting as a
  /// governed, scoped proxy of the principal.
  @override
  FutureOr<Tissue<E>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  /// Provides structural equality for tissues.
  ///
  /// Equality is determined by:
  /// 1.  **Identity:** If both references point to the same object.
  /// 2.  **Unmodifiable Linkage:** If [other] is an [Unmodifiable] view
  ///     pointing back to `this`.
  /// 3.  **Content Equality:** If [other] is a standard [Iterable], equality
  ///     is delegated to the underlying `_nucleus.container`.
  ///
  /// ### When to use
  /// This operator is called automatically when comparing tissues for equality.
  /// You rarely need to invoke it directly.
  ///
  /// ### How it works
  /// - First checks if the objects are identical (same instance).
  /// - If [other] is an [Unmodifiable] view of `this`, returns `true`.
  /// - If [other] is an [Iterable], delegates to the underlying container's
  ///   equality logic.
  /// - Otherwise, returns `false`.
  ///
  /// ### Parameters:
  /// - [other]: The object to compare with this tissue.
  ///
  /// ### Returns:
  /// `true` if the tissues are equal; `false` otherwise.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is Tissue<E>) {
      if (other is Unmodifiable) {
        if (other._nucleus.bind != null &&
            identical(this, other._nucleus.bind)) {
          return identical(other, unmodifiable);
        }
      }
    }
    if (other is Iterable<E>) {
      return _nucleus.container == other;
    }
    return false;
  }

  /// Returns the hash code based on the underlying [Container].
  @override
  int get hashCode => _nucleus.container.hashCode;

  /// Returns a string representation of the underlying collection.
  @override
  String toString() {
    return _nucleus.container.toString();
  }

  /// Returns an [Iterator] that allows iterating over the elements of this tissue.
  @override
  Iterator<E> get iterator {
    return _nucleus.container.iterator;
  }
}

/// A reusable **Architectural Segment** (Genetic Sequence) providing the
/// standardized operational logic and structural equality for all
/// [Tissue] implementations.
///
/// In the framework's biological metaphor, [TissueMixin] acts as a
/// **Common Genetic Trait**. It ensures that diverse collection types
/// (Lists, Sets, Maps) exhibit identical behaviors for core operations
/// like identity, hashing, and forensic comparison.
///
/// ### When to use
/// - **Custom Tissues**: Apply this mixin when implementing specialized
///   collection types that must adhere to the standard [Tissue] contract.
/// - **Behavioral Shadowing**: Use it to ensure that specialized decorators
///   or proxies maintain the same forensic identity as their underlying source.
///
/// ### How it works
/// - **Identity Logic**: Overrides [operator ==] to implement the framework's
///   **Forensic Equality**. A tissue is equal to another if they share the
///   same instance, if one is an [Unmodifiable] view of the other, or if
///   their underlying [Container] data matches.
/// - **Storage Delegation**: Forwards core `Iterable` methods (iterator,
///   toString, hashCode) directly to the [TissueNucleusBase.container],
///   ensuring that the behavior reflects the physical storage defined in the DNA.
/// - **Nucleus Binding**: Requires an implementation of [_nucleus] to access
///   the governing configuration and principal chain.
///
/// ### Type Parameters:
/// - [E]: The type of elements held within the collection.
/// - [I]: The internal [Iterable] implementation (e.g., `List<E>`).
/// - [C]: The target [Tissue] interface.
///
/// See also:
/// - [TissueBase] – The primary class where this mixin's traits are applied.
/// - [UnmodifiableTissueBase] – A consumer of this mixin for read-only projections.
mixin TissueMixin<E, I extends Iterable<E>, C extends Tissue<E>> on Tissue<E> {
  @override
  TissueNucleusBase<E, I, C> get _nucleus;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is Tissue<E>) {
      if (other is Unmodifiable) {
        if (other._nucleus.bind != null &&
            identical(this, other._nucleus.bind)) {
          return identical(other, unmodifiable);
        }
      }
    }
    if (other is Iterable<E>) {
      return _nucleus.container == other;
    }
    return false;
  }

  /// Returns the hash code based on the underlying [Container].
  @override
  int get hashCode => _nucleus.container.hashCode;

  /// Returns a string representation of the underlying collection.
  @override
  String toString() {
    return _nucleus.container.toString();
  }

  /// Returns an [Iterator] that allows iterating over the elements of this tissue.
  @override
  Iterator<E> get iterator {
    return _nucleus.container.iterator;
  }
}

/// A concrete implementation of an unmodifiable (read‑only) tissue view.
///
/// [_UnmodifiableTissue] is the primary implementation of the `.unmodifiable`
/// getter on all tissues. It provides a live, read‑only projection that shares
/// the same physical storage as the mutable source.
///
/// ### When to use
/// This is an internal class. You obtain unmodifiable views via the
/// `.unmodifiable` getter on any [Tissue] – you never instantiate this directly.
///
/// ### How it works
/// - It shares the same physical storage and lock as the mutable source.
/// - The `modifiable` getter returns an empty set – all mutations are rejected.
/// - The view is **live** – changes to the source are immediately reflected.
/// - If `unmodifiableElement` is `true`, child [Cell]s are projected as
///   read‑only deputies.
///
/// ### Type Parameters:
/// * [E]: The element type.
/// * [C]: The concrete tissue interface.
class _UnmodifiableTissue<E, C extends Tissue<E>>
    extends UnmodifiableTissueBase<E, Iterable<E>, C> {
  _UnmodifiableTissue(Iterable<E> elements,
      {bool unmodifiableElement = true, TissueNucleus<E>? nucleus})
      : this.fromNucleus(
            (nucleus ??
                    TissueNucleus.create<E, Iterable<E>, C>(
                        container: Container.iterable))
                as TissueNucleusBase<E, Iterable<E>, C>,
            unmodifiableElement: unmodifiableElement,
            elements: elements);

  _UnmodifiableTissue.view(Tissue<E> bind,
      {Context? context, bool unmodifiableElement = true})
      : this.fromNucleus(
            TissueNucleus.create<E, Iterable<E>, C>(
                bind: bind,
                context: context,
                synapses: bind._nucleus.synapses == Synapses.disabled
                    ? Synapses.disabled
                    : Synapses.enabled,
                principal:
                    bind._nucleus as TissueNucleusBase<E, Iterable<E>, C>),
            unmodifiableElement: unmodifiableElement,
            elements: unmodifiableElement
                ? bind.map<E>((e) => e is Cell ? e.unmodifiable as E : e)
                : null);

  _UnmodifiableTissue.fromNucleus(TissueNucleus<E> nucleus,
      {super.unmodifiableElement, super.elements})
      : super(nucleus as TissueNucleusBase<E, Iterable<E>, C>);

  @override
  FutureOr<Tissue<E>> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestTissue<E, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _TissueDeputy<E, Iterable<E>, C>._(this,
        context: context,
        testRule: testRule,
        ephemeralPolicy: ephemeralPolicy,
        synapses: synapses);
  }

  @override
  TestTissue<E, C> get validate => _nucleus.testRule;

  @override
  Tissue<E> get unmodifiable => this;
}

/// A specialised foundational base class for constructing high‑fidelity,
/// **Read‑Only Reactive Projections** (Deputies) of a [Tissue].
///
/// [UnmodifiableTissueBase] is a cornerstone of the framework's
/// **Security Scoping** and **Deep Immutability** architecture. It extends the
/// core [TissueBase] engine but overrides the implementation to strictly
/// prohibit structural mutations, effectively acting as a "Read‑Only Lens" or
/// "Security Shadow" over a piece of reactive state.
///
/// ### When to use
/// This class is used internally to create read‑only views. You don't need to
/// instantiate it manually – just use the `.unmodifiable` getter.
///
/// You never extend this class directly. It is used internally to implement
/// the `.unmodifiable` getter on all tissues. The concrete subclasses
/// (e.g., `_UnmodifiableTissueList`) are returned when you call `myList.unmodifiable`.
///
/// ### How it works
/// - It shares the same physical storage and lock as the mutable source.
/// - It overrides `modifiable` to return an empty set – all mutations are rejected.
/// - The `iterator` wraps elements in `unmodifiable` if `unmodifiableElement` is true.
/// - It implements a specialised `operator ==` that recognises identity with
///   the mutable source, so `source == source.unmodifiable` is `true`.
/// - The `async` getter returns a specialised version that throws on mutations.
///
/// ### Type Parameters:
/// * [E]: The type of elements contained within the tissue.
/// * [I]: The internal [Iterable] implementation type (e.g., `List<E>`, `Set<E>`).
/// * [C]: The specific implementation interface of the [Tissue]
///   (e.g., `TissueList<E>`), used for self‑referential type safety.
abstract class UnmodifiableTissueBase<E, I extends Iterable<E>,
        C extends Tissue<E>> extends TissueBase<E, I, C>
    implements UnmodifiableTissue<E> {
  /// Returns an empty iterable of functions, indicating that this tissue
  /// does not support any modifiable operations.
  @override
  Iterable<Function> get modifiable => const Iterable<Function>.empty();

  /// The generic dispatch engine for the base [Tissue] implementations.
  ///
  /// It mirrors the retired dynamic gateway semantics: whitelisted functions
  /// pass through the integrity gate, everything else executes directly.
  @override
  dynamic dispatch(
    Function function, {
    List? positionalArguments,
    Map<Symbol, dynamic>? namedArguments,
  }) {
    if (!modifiable.contains(function)) {
      return Function.apply(function, positionalArguments, namedArguments);
    }
    final validation = validate.action(
      function,
      host: this,
      arguments: (
        positionalArguments: positionalArguments,
        namedArguments: namedArguments,
      ),
    );
    if (validation is Future<bool>) {
      return validation.then((passed) => passed
          ? Function.apply(function, positionalArguments, namedArguments)
          : null);
    }
    return validation == true
        ? Function.apply(function, positionalArguments, namedArguments)
        : null;
  }

  /// Determines whether elements that are [Cell]s should be wrapped in their
  /// unmodifiable views.
  ///
  /// If `true`, any element of type [Cell] passed during initialization is
  /// transformed via `element.unmodifiable`.
  final bool unmodifiableElement;

  /// Creates an [UnmodifiableTissueBase] with the specified nucleus.
  ///
  /// This is an internal constructor. Subclasses call it with their specific
  /// nucleus type. You never call it directly.
  ///
  /// ### Parameters:
  /// - [nucleus]: The configuration nucleus for the tissue.
  /// - [unmodifiableElement]: Whether to recursively apply unmodifiability
  ///   to [Cell] elements. Defaults to `true`.
  /// - [elements]: The initial data. If [unmodifiableElement] is true,
  ///   elements are mapped to their read‑only versions before being stored
  ///   in the container.
  UnmodifiableTissueBase(super.nucleus,
      {this.unmodifiableElement = true, Iterable<E>? elements})
      : super(elements: elements) {
    if (unmodifiableElement) {
      final bind = get<Cell?>(() => _nucleus.record.local.bind, orElse: null);
      if (bind != null && elements != null && identical(bind, elements)) {
        elements
            .whereType<Cell>()
            .forEach((e) => _nucleus.synapses.link(e, downstreamCell: this));
      }
    }
  }

  /// Compares this unmodifiable tissue with another object for equality.
  ///
  /// Equality is established if:
  /// 1.  The objects are identical references.
  /// 2.  The [other] object is a mutable [Tissue] that acts as the source
  ///     (bound) for this unmodifiable view.
  /// 3.  The [other] object is an [Iterable] and its contents match the
  ///     internal container of this tissue.
  ///
  /// ### When to use
  /// This operator is called automatically when comparing tissues for equality.
  /// You rarely need to invoke it directly.
  ///
  /// ### How it works
  /// - First checks if the objects are identical (same instance).
  /// - If [other] is a mutable [Tissue] that this unmodifiable view mirrors,
  ///   returns `true`.
  /// - If [other] is an [Iterable], delegates to the underlying container's
  ///   equality logic.
  /// - Otherwise, returns `false`.
  ///
  /// ### Parameters:
  /// - [other]: The object to compare with this unmodifiable tissue.
  ///
  /// ### Returns:
  /// `true` if the tissues are equal; `false` otherwise.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is Tissue<E>) {
      // Check if we are the unmodifiable view of the other tissue
      if (other is! Unmodifiable) {
        if (_nucleus.bind != null && identical(_nucleus.bind, other)) {
          return identical(other.unmodifiable, this);
        }
      }
    }
    if (other is Iterable<E>) {
      return _nucleus.container == other;
    }
    return false;
  }

  /// Returns a hash code derived from the underlying [Container].
  @override
  int get hashCode => _nucleus.container.hashCode;

  /// Returns an [Iterator] that allows for a safe, read‑only traversal of the
  /// elements within this tissue.
  ///
  /// As this property belongs to an unmodifiable implementation, the resulting
  /// iterator acts as a secure "lens" into the underlying storage. It provides
  /// access to the current state of the collection without exposing any
  /// capabilities for structural mutation.
  ///
  /// ### Purpose & Recursive Safety:
  /// The primary purpose of this getter is to ensure **Deep Immutability**
  /// across the reactive graph. In a system where collections often contain
  /// other reactive nodes (such as [Cell]s, `Field`s, or `Model`s), a simple
  /// read‑only list is insufficient if the elements themselves remain mutable.
  ///
  /// To solve this, the iterator implements the following architectural logic:
  /// 1. **Element Transformation**: If the tissue is configured with
  ///    `unmodifiableElement: true`, the iterator intercepts every element
  ///    during traversal.
  /// 2. **Deputy Projection**: If an element is a [Cell], the iterator
  ///    automatically yields its `.unmodifiable` deputy instead of the
  ///    original instance.
  /// 3. **Leakage Prevention**: This prevents "behavioral leakage," where a
  ///    consumer might obtain a mutable reference to a domain object simply
  ///    by iterating through an immutable collection.
  ///
  /// ### Returns:
  ///   An [Iterator<E>] that yields elements (or their unmodifiable proxies)
  ///   from the tissue.
  @override
  Iterator<E> get iterator {
    final container = get<TissueContainer?>(
        () => _nucleus.record.local.container,
        orElse: null);
    if (container != null) {
      if (unmodifiableElement) {
        return (container.store as Iterable)
            .map((e) => e is Cell ? e.unmodifiable as E : e as E)
            .iterator;
      }
      return (container.store as Iterable).map((e) => e as E).iterator;
    }
    if (unmodifiableElement) {
      final elements = _nucleus.container
          .map((e) => e is Cell ? e.unmodifiable : e)
          .cast<E>();
      return elements.iterator;
    }
    return _nucleus.container.iterator;
  }
}

/// A specialised handler for performing asynchronous mutation operations on a [Tissue].
///
/// [TissueModifiableAsync] extends [ModifiableAsync], providing a bridge between
/// the reactive tissue and asynchronous data processing. It allows developers
/// to trigger updates or modifications to a collection that involve [Future]s or
/// other non‑blocking operations, while remaining integrated with the [Cell] system's
/// transaction and notification cycles.
///
/// ### When to use
/// - You are in an `async` context (e.g., a network callback) and need to
///   wait for the mutation to be fully processed.
/// - You want to avoid blocking the UI thread during a batch of updates.
/// - The mutation involves I/O or other asynchronous side effects.
///
/// You never construct this directly. It is returned by the `async` getter on
/// any [Tissue] (e.g., `myList.async`). Use it when you need to perform
/// operations asynchronously.
///
/// ### How it works
/// - It wraps the synchronous mutation methods in a `Future`.
/// - All operations are scheduled through the tissue's lock, ensuring
///   atomicity.
/// - The returned `Future` completes when the mutation has been validated,
///   applied, and propagated through the reactive graph.
///
/// ### Example
/// ```dart
/// final list = TissueList<int>();
/// await list.async.add(42);
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements contained within the targeted tissue.
/// * [C]: The specific implementation type of the [Tissue] being modified.
class TissueModifiableAsync<E, C extends Tissue<E>> extends ModifiableAsync<C> {
  /// The target tissue instance that this async handler manages.
  final C _tissue;

  /// Creates a new [TissueModifiableAsync] instance for the given [tissue].
  ///
  /// This constructor is typically called internally by the `async` getter
  /// on a [Tissue] instance.
  ///
  /// * [tissue]: The [Tissue] that will be the target of asynchronous
  ///   modifications.
  const TissueModifiableAsync(super.tissue) : _tissue = tissue;
}
