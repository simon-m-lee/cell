// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

// ignore_for_file: unused_element
// ignore_for_file: unused_field
// ignore_for_file: prefer_final_fields

/// Internal implementation of [TissueValueNucleus] for reactive single values.
///
/// [_TissueValueNucleus] is the concrete nucleus that powers `_TissueValue`.
/// It extends [TissueValueNucleusBase] and provides the specific logic for
/// cloning and evolution.
///
/// ### When to use
/// This is an internal class. You don't instantiate it directly – use the
/// factories on [TissueValueNucleus] instead.
///
/// ### How it works
/// - It extends [TissueValueNucleusBase] and provides the concrete implementation.
/// - The `clone` getter creates a fresh copy with its own lock and synapses.
/// - The `evolve` constructor creates a deputy nucleus with overridden properties.
///
/// ### Type Parameters:
/// * [V]: The value type.
/// * [C]: The concrete tissue value type.
class _TissueValueNucleus<V, C extends TissueValue<V>>
    extends TissueValueNucleusBase<V, C> {
  _TissueValueNucleus({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    super.ephemeralPolicy,
    super.forceLock,
    super.user,
    super.finalValue,
    super.principal,
  }) : super();

  _TissueValueNucleus.fromRecord(super.record) : super.fromRecord();

  /// Creates an independent, decoupled clone of this nucleus.
  ///
  /// ### When to use
  /// This is used internally when creating a new value from a template nucleus.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a value instance.
  ///
  /// ### Returns:
  /// A new [TissueValueNucleusBase] instance with identical behavioural logic.
  @override
  TissueValueNucleusBase<V, C> get clone {
    final p = principal;
    return TissueValueNucleus.create<V, C>(
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

/// The foundational blueprint that defines the behaviour, storage strategy,
/// and governance of a reactive single‑value cell.
///
/// [TissueValueNucleusBase] holds the immutable configuration – the receptor,
/// validation rule, context, synapses, and the finalValue flag – that governs
/// how a [TissueValue] reacts to mutations. It is the **DNA** of every reactive
/// single‑value container.
///
/// ### When to use
/// Only if you are building a custom value type that needs to override the
/// default nucleus behaviour. For standard use, the provided factories
/// are sufficient.
///
/// You never extend this class directly. The framework provides concrete
/// implementations via [TissueValueNucleus.create] and the [TissueValue] factories.
/// This class is the base that powers the internal `_TissueValueNucleus`.
///
/// ### How it works
/// - It extends [TissueNucleusBase] to inherit the core property resolution
///   engine (bitmask records, principal chain, lock management).
/// - It specialises the storage type to [ValueContainer<V>] and forces the
///   container strategy to either [Container.value] (mutable) or
///   [Container.finalValue] (write‑once) based on the `finalValue` flag.
/// - It implements the [containerType] resolution by walking up the
///   `principal` chain, defaulting to [Container.value].
/// - It provides the `clone` getter to create an independent copy of the
///   nucleus with a fresh lock and synapses, essential for creating new
///   value instances from a template.
///
/// ### Example: Reusing a validated nucleus
/// ```dart
/// final validNucleus = TissueValueNucleus.create<int>(
///   testRule: TestTissue<int>((v) => v >= 0),
///   finalValue: true,
/// );
/// final value1 = TissueValue.fromNucleus(validNucleus, value: 42);
/// final value2 = TissueValue.fromNucleus(validNucleus, value: 100);
/// ```
///
/// ### Type Parameters:
/// - [V]: The type of the value held within the associated [TissueValue].
/// - [C]: The specific [TissueValue] implementation type (usually `TissueValue<V>`),
///   allowing for type‑safe pulse processing within the hierarchy.
abstract class TissueValueNucleusBase<V, C extends TissueValue<V>>
    extends TissueNucleusBase<V, ValueContainer<V>, C>
    implements TissueValueNucleus<V> {
  /// **Primary Blueprint Constructor** – Synthesizes the immutable DNA and
  /// storage strategy for a reactive single-value cell.
  ///
  /// In the framework's biological metaphor, this constructor defines the
  /// **Initial DNA** of a value container. It establishes whether the cell
  /// represents a mutable state or a write-once forensic constant, setting
  /// the foundation for all behavioral deputies derived from this nucleus.
  ///
  /// ### When to use
  /// - **Internal Implementation**: This constructor is `public` specifically
  ///   to allow concrete subclasses (like `_TissueValueNucleus`) to invoke it
  ///   via `super()`.
  /// - **Custom Value Nuclei**: Use this if you are extending the framework to
  ///   create a specialized value type with unique storage or lifecycle needs.
  ///
  /// **Note**: Standard application code should use [TissueValueNucleus.create]
  /// or [TissueValueNucleus.evolve] instead of calling this directly.
  ///
  /// ### How it works
  /// 1. **Structural Selection**: The [finalValue] flag determines the
  ///    physical [Container] strategy:
  ///    - `true` → [Container.finalValue]: The value is a write-once constant.
  ///    - `false` → [Container.value]: The value is mutable.
  /// 2. **Bitmask Encoding**: All governance parameters are passed to the
  ///    [TissueNucleusBase] super-constructor, where they are packed into
  ///    a memory-optimized, bitmask-enabled record.
  /// 3. **Immutability**: Once constructed, the storage strategy is locked.
  ///    Any future [TissueValueNucleus.evolve] operations will maintain this core DNA.
  ///
  /// ### Example (Internal Subclass)
  /// ```dart
  /// class MyCustomValueNucleus<V> extends TissueValueNucleusBase<V, TissueValue<V>> {
  ///   MyCustomValueNucleus({
  ///     super.finalValue = false,
  ///     super.testRule,
  ///     // ...other params
  ///   }) : super();
  /// }
  /// ```
  ///
  /// ### Parameters:
  /// - [bind]: **Ingress Link.** An optional upstream [Cell] for the value to
  ///   observe and mirror (Deputy pattern).
  /// - [context]: **Operational Authority.** The security tier and priority
  ///   domain (default: [Context.system]).
  /// - [receptor]: **Command Engine.** The logic used to process mutations.
  /// - [testRule]: **Integrity Gate.** Validation rules that guard the value.
  /// - [synapses]: **Signal Distribution.** Manages egress connectivity and
  ///   event broadcasting.
  /// - [finalValue]: If `true`, the value becomes a write-once forensic
  ///   constant. Defaults to `false` (mutable).
  /// - [ephemeralPolicy]: **Lifecycle Governance.** Defines the TTL for
  ///   the cell state.
  /// - [forceLock]: If `true`, shares the [principal]'s synchronization lock;
  ///   otherwise, allocates a new one.
  /// - [user]: **Extension Metadata.** Optional record for domain-specific tags.
  /// - [principal]: **Prototype Source.** The parent nucleus from which this
  ///   instance inherits its structural DNA.
  TissueValueNucleusBase({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    bool finalValue = false,
    super.ephemeralPolicy,
    super.forceLock,
    super.user,
    super.principal,
  }) : super(container: finalValue ? Container.finalValue : Container.value);

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
  /// final record = (mask: (container: Container.value, ...), principal: null);
  /// final nucleus = TissueValueNucleusBase.fromRecord(record: record);
  /// ```
  ///
  /// ### Parameters:
  /// - [record]: The internal property record – an implementation‑specific
  ///   Dart `Record` containing all nucleus fields.
  const TissueValueNucleusBase.fromRecord(super.record) : super.fromRecord();

  /// Retrieves the hierarchical principal configuration of this value's properties.
  ///
  /// This getter is a specialized, type‑safe override of the core [Nucleus.principal]
  /// link. It facilitates the "Property Cascading" mechanism that allows
  /// [TissueValue] instances to participate in an inheritance‑based
  /// configuration model.
  ///
  /// ### When to use
  /// Only if you are building a custom value implementation and need to
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
  /// 2. **Contextual Overrides**: A "Deputy" value (created via `deputy()`)
  ///    typically has a [principal] link to the original value's nucleus,
  ///    allowing it to inherit the physical data [container] and `finalValue`
  ///    while providing a local override for the [context] or [testRule].
  /// 3. **Termination**: The chain ends when this getter returns `null` –
  ///    that's the "root" nucleus.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final value = TissueValue<int>(42);
  /// final deputy = value.deputy(testRule: TestTissue.readOnly);
  /// // deputy._nucleus.principal points back to value._nucleus
  /// // So when deputy needs the finalValue flag, it delegates to value._nucleus.
  /// ```
  ///
  /// ### Returns:
  /// The parent nucleus that this configuration extends, or `null` if this is
  /// a root nucleus with no ancestors.
  @override
  TissueValueNucleusBase<V, C>? get principal =>
      super.principal as TissueValueNucleusBase<V, C>?;

  /// The physical storage strategy (mutable or write‑once) used by this value.
  ///
  /// This getter resolves the [Container] type by walking up the `principal`
  /// chain. It determines whether the value can be changed after initialisation.
  ///
  /// ### When to use
  /// Read this to understand whether the value is mutable or write‑once.
  /// This is useful for conditional UI logic (e.g., disabling an "Edit" button)
  /// or for debugging.
  ///
  @override
  Container get containerType {
    return get<Container>(() => record.local.inheritable.container,
        fallback: () => principal?.containerType, orElse: Container.value);
  }
}

/// Concrete implementation of a mutable reactive single value.
///
/// [_TissueValue] is the live instance you get from factories like `TissueValue()`.
/// It ties together the nucleus (logic) and the container (data) to provide
/// a fully reactive, thread‑safe value with validation and event emission.
///
/// ### When to use
/// You never create this directly – use [TissueValue] or one of its named
/// constructors (`TissueValue.empty`, `TissueValue.fromNucleus`).
///
/// ### How it works
/// - It extends [TissueValueBase] and provides the mutable implementation.
/// - It holds a [TissueValueNucleus] that defines the value's behaviour.
/// - It implements `deputy()` to create restricted views.
/// - It provides the `async` getter for non‑blocking operations.
///
/// ### Type Parameters:
/// * [V]: The value type.
/// * [C]: The concrete tissue value type.
class _TissueValue<V, C extends TissueValue<V>> extends TissueValueBase<V, C> {
  _TissueValue(
    V? value, {
    Cell? bind,
    Context context = Context.system,
    TestTissue<V, C> testRule = TestTissue.allowAll,
    TissueReceptor<V, C> receptor = TissueReceptor.passThrough,
    Synapses synapses = Synapses.enabled,
    bool finalValue = false,
  }) : this.fromNucleus(
            _TissueValueNucleus<V, C>(
              bind: bind,
              testRule: testRule,
              receptor: receptor,
              synapses: synapses,
              finalValue: finalValue,
            ),
            value: value);

  _TissueValue.empty({
    Cell? bind,
    Context context = Context.system,
    TestTissue<V, C> testRule = TestTissue.allowAll,
    TissueReceptor<V, C> receptor = TissueReceptor.passThrough,
    Synapses synapses = Synapses.enabled,
    bool finalValue = false,
  }) : this.fromNucleus(_TissueValueNucleus<V, C>(
          bind: bind,
          testRule: testRule,
          receptor: receptor,
          synapses: synapses,
          finalValue: finalValue,
        ));

  _TissueValue.fromNucleus(super.properties, {super.value}) : super();

  @override
  FutureOr<TissueValue<V>> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestTissue<V, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _TissueValueDeputy<V, C>._(this,
        context: context,
        testRule: testRule,
        ephemeralPolicy: ephemeralPolicy,
        synapses: synapses);
  }

  @override
  late final TissueValue<V> unmodifiable =
      _UnmodifiableTissueValue<V, C>.view(this, unmodifiableElement: true);

  /// Returns an asynchronous wrapper for this value.
  ///
  /// The [async] property allows users to perform value operations (like `set`)
  /// that return a [Future]. This is particularly useful when mutations are
  /// bound to external cells or require synchronization across different
  /// execution contexts.
  @override
  ValueCellAsync<V> get async => ValueCellAsync<V>(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is TissueValue<V>) {
      if (other is Unmodifiable) {
        if (other._nucleus.bind != null &&
            identical(this, other._nucleus.bind)) {
          return other.value == value;
        }
      }
      return other.value == value;
    }
    if (other is V && value != null) {
      return other == value;
    }
    return false;
  }

  @override
  int get hashCode => value?.hashCode ?? _nucleus.container.hashCode;
}

/// The foundational reactive engine for all single‑value containers in the
/// `cell_tissue` ecosystem.
///
/// [TissueValueBase] provides the concrete integration between the reactive
/// [TissueBase] framework and the standard [ValueCell] contract. It uses
/// [TissueValueMixin] to implement the value‑specific operations, creating a
/// high‑performance, governed, and observable single‑value cell.
///
/// ### When to use
/// Only if you are extending the framework to build a custom value variant
/// that requires precise control over the mutation pipeline or storage
/// behaviour. For standard use cases, the existing [TissueValue] factories
/// are sufficient.
///
/// You never use this class directly. It is the base class for the internal
/// implementations that power both mutable values (`_TissueValue`) and read‑only
/// views (`_UnmodifiableTissueValue`). Your interaction with values is through
/// the factories on [TissueValue].
///
/// ### How it works
/// - It extends [TissueBase] to inherit the core reactive lifecycle,
///   synchronisation domain, and nucleus‑container architecture.
/// - It mixes in [TissueValueMixin], which provides the [ValueCell] API and
///   routes all mutations (like `set` or `value =`) through the `apply`
///   command gateway.
/// - Every change to the value is:
///   1. Validated against the [TestTissue] rules.
///   2. Applied atomically to the [ValueContainer].
///   3. Dispatched as a [Tissue.elementUpdated] to all observers.
/// - The underlying storage is a [ValueContainer<V>] (a single‑value holder).
///
/// ### Example (Internal Usage)
/// While you never instantiate this directly, understanding it helps you
/// reason about how `TissueValue` works:
/// ```dart
/// final nucleus = TissueValueNucleus.create<int>(finalValue: false);
/// final value = _TissueValue<int>(nucleus);
/// value.value = 42; // Routed through `apply` -> validation -> pulse emission
/// ```
///
/// ### Type Parameters:
/// - [V]: The type of the value contained in the cell.
/// - [C]: The specific [Tissue] implementation type (usually `TissueValue<V>`),
///   allowing for type‑safe pulse processing within the hierarchy.
abstract class TissueValueBase<V, C extends TissueValue<V>>
    extends TissueBase<V, ValueContainer<V>, C>
    with TissueValueMixin<V, C>
    implements TissueValue<V> {
  @override
  TissueValueNucleusBase<V, C> get _nucleus =>
      super._nucleus as TissueValueNucleusBase<V, C>;

  /// Constructs a [TissueValueBase] with the given [properties] and
  /// an optional initial [value].
  ///
  /// If [value] is provided, it is stored in the underlying container.
  /// If the value is a [Cell], it is automatically linked to this
  /// tissue's synapses to ensure reactivity propagates from the element.
  ///
  /// Parameters:
  ///   - `properties`: A [TissueValueNucleus<V>] object that holds the
  ///     configuration for this `TissueValue`. This is a required parameter.
  ///   - `value`: An optional initial value `V?` to store in the `TissueValue`.
  ///     If `null` or omitted, the `TissueValue` is initialized without a value.
  TissueValueBase(TissueValueNucleus<V> properties, {V? value})
      : super(properties as TissueValueNucleusBase<V, C>) {
    if (value != null) {
      properties.container.store.value = value;
      if (value is Cell) {
        _nucleus.synapses.link(value, downstreamCell: this);
      }
    }
  }

  /// Returns an asynchronous wrapper for this value.
  ///
  /// The [async] property allows users to perform value operations (like `set`)
  /// that return a [Future]. This is particularly useful when mutations are
  /// bound to external cells or require synchronization across different
  /// execution contexts.
  ///
  /// ### Example
  /// ```dart
  /// final value = TissueValue<int>(0);
  /// await value.async.set(42);
  @override
  ValueCellAsync<V> get async => ValueCellAsync<V>(this);

  /// Returns the validation rule currently applied to this list.
  ///
  /// This rule is checked before elements are added or modified.
  @override
  TestTissue<V, C> get validate => _nucleus.testRule;

  /// Determines whether this `TissueValueBase` instance is equal to another `Object`.
  ///
  /// The equality comparison follows these rules:
  /// 1.  **Identity Check**: If `identical(this, other)` is `true`, they are equal.
  /// 2.  **`TissueValue` Check**: If `other` is also a `TissueValue<V>`:
  ///     -   If `other` is an `Unmodifiable` view (e.g., created by
  ///         `TissueValue.unmodifiable(this)`), it checks if the `bind`
  ///         property of `other` points to `this` instance.
  /// 3.  **Value Check**: If `other` is of type `V` (the same type as the value
  ///     held by this `TissueValue`) and `this.value` is not `null`, it
  ///     compares `other == this.value`.
  /// 4.  **Default**: If none of the above conditions are met, they are considered
  ///     not equal (`false`).
  ///
  /// This operator aims to provide meaningful equality semantics, considering both
  /// the `TissueValue` wrapper itself and the underlying value it holds.s instance based on the
  ///   rules described above; `false` otherwise.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is TissueValue<V>) {
      if (other is Unmodifiable) {
        if (other._nucleus.bind != null &&
            identical(this, other._nucleus.bind)) {
          return other.value == value;
        }
      }
      return other.value == value;
    }
    if (other is V && value != null) {
      return other == value;
    }
    return false;
  }

  /// Computes the hash code for this `TissueValueBase` instance.
  ///
  /// The hash code is derived as follows:
  /// -   If `this.value` is not `null`, the hash code of `this.value` is used.
  /// -   If `this.value` is `null`, the hash code of the underlying data container
  ///     is used. This ensures that even `TissueValue` instances with `null` values
  ///     have a consistent hash code based on their container identity.
  ///
  /// This implementation aims to provide a hash code that is consistent with the
  /// equality operator (`operator==`).
  @override
  int get hashCode => value?.hashCode ?? _nucleus.container.hashCode;
}

/// Internal deputy implementation for [TissueValue].
///
/// A deputy shares the same physical data as its principal but applies
/// different validation, context, or synapses. It is created via the
/// `deputy()` method on a [TissueValue].
///
/// ### When to use
/// This is an internal class. You obtain deputies via the `deputy()` method on
/// any [TissueValue] – you never instantiate this directly.
///
/// ### How it works
/// - It extends `_TissueValue` and mixes in `Deputy`.
/// - The deputy's [TestTissue] is the composition of the principal's rule and
///   the deputy's additional rule (you can only narrow permissions).
/// - The deputy gets its own [Synapses] registry by default.
/// - The deputy is logically equal to its principal.
///
/// ### Type Parameters:
/// * [V]: The value type.
/// * [C]: The concrete tissue value type.
class _TissueValueDeputy<V, C extends TissueValue<V>> extends _TissueValue<V, C>
    with Deputy<TissueValue<V>> {
  _TissueValueDeputy._(TissueValueBase<V, C> bind,
      {Context context = Context.system,
      TestTissue<V, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled})
      : super.fromNucleus(_TissueValueNucleus<V, C>.fromRecord((
          local: TissueNucleusBase.mask<V, ValueContainer<V>, C>(
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
  FutureOr<TissueValue<V>> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestTissue<V, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _TissueValueDeputy<V, C>._(_nucleus.bind as TissueValueBase<V, C>,
        context: context,
        testRule: testRule,
        ephemeralPolicy: ephemeralPolicy,
        synapses: synapses);
  }
}

/// Internal implementation of an unmodifiable (read‑only) reactive value.
///
/// This is created when you call `.unmodifiable` on a [TissueValue]. It
/// shares the same physical storage and lock as the source, but blocks all
/// mutation attempts. It is a live view – changes to the source are
/// immediately reflected.
///
/// ### When to use
/// This is an internal class. You obtain unmodifiable views via the
/// `.unmodifiable` getter on any [TissueValue] – you never instantiate
/// this directly.
///
/// ### How it works
/// - It extends [UnmodifiableTissueValueBase] and provides the concrete
///   implementation.
/// - It shares the same physical storage and lock as the mutable source.
/// - The view is **live** – changes to the source are immediately reflected.
/// - If `unmodifiableElement` is `true`, and the value is a [Cell], it is
///   projected as read‑only.
///
/// ### Type Parameters:
/// * [V]: The value type.
/// * [C]: The concrete tissue value type.
class _UnmodifiableTissueValue<V, C extends TissueValue<V>>
    extends UnmodifiableTissueValueBase<V, C> {
  _UnmodifiableTissueValue(V value,
      {bool unmodifiableElement = true, TissueValueNucleus<V>? properties})
      : this.fromNucleus(
            (properties ?? TissueValueNucleus.create<V, C>())
                as TissueValueNucleusBase<V, C>,
            unmodifiableElement: unmodifiableElement,
            value: value);

  _UnmodifiableTissueValue.view(TissueValue<V> bind,
      {Context? context, bool unmodifiableElement = true})
      : this.fromNucleus(
            TissueValueNucleus.create<V, C>(
                bind: bind,
                context: context,
                synapses: bind._nucleus.synapses == Synapses.disabled
                    ? Synapses.disabled
                    : Synapses.enabled,
                principal: bind._nucleus as TissueValueNucleusBase<V, C>),
            unmodifiableElement: unmodifiableElement,
            value: unmodifiableElement
                ? bind.value is Cell
                    ? (bind.value! as Cell).unmodifiable as V
                    : bind.value
                : null);

  _UnmodifiableTissueValue.fromNucleus(TissueValueNucleus<V> properties,
      {super.unmodifiableElement, super.value})
      : super(properties as TissueValueNucleusBase<V, C>);

  @override
  FutureOr<TissueValue<V>> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestTissue<V, C> testRule = TestTissue.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _TissueValueDeputy<V, C>._(_nucleus.bind as TissueValueBase<V, C>,
        context: context,
        testRule: testRule,
        ephemeralPolicy: ephemeralPolicy,
        synapses: synapses);
  }

  @override
  TissueValue<V> get unmodifiable => this;

  @override
  TestTissue<V, C> get validate => _nucleus.testRule;

  @override
  ValueCellAsync<V> get async => _UnmodifiableModifiableValueAsync(this);
}

/// The foundational base class for all read‑only reactive value views.
///
/// [UnmodifiableTissueValueBase] is the abstract anchor for unmodifiable
/// value implementations (e.g., `_UnmodifiableTissueValue`). It ties together
/// a read‑only nucleus and a shared storage container, ensuring that all
/// mutations are blocked while reactivity remains live.
///
/// ### When to use
/// Only if you are building a custom read‑only value variant that needs
/// to override the default unmodifiable behaviour. For everyday use,
/// the existing `.unmodifiable` getter is all you need.
///
/// This class is **abstract** – you never instantiate it directly.
/// You obtain an unmodifiable value by calling `.unmodifiable` on any
/// mutable [TissueValue], or by using one of the dedicated factories
/// (`UnmodifiableTissueValue`, `UnmodifiableTissueValue.view`, etc.).
///
/// ### How it works
/// 1. The constructor receives a [TissueValueNucleusBase] that defines the
///    value's structural strategy (`finalValue`) and governance rules.
/// 2. The `unmodifiableElement` flag controls deep immutability:
///    - If `true`, and the value is a [Cell], it is automatically projected
///      as its `.unmodifiable` deputy when accessed via this value.
///    - If `false`, child cells remain mutable (but the value itself is
///      still read‑only).
/// 3. The value shares the same physical storage as its mutable source
///    (when created via `.view`) – changes to the source are immediately
///    reflected in this read‑only view.
///
/// ### Example (Internal)
/// ```dart
/// final source = TissueValue<int>(42);
/// final readOnly = _UnmodifiableTissueValue<int>.view(source);
/// // readOnly.value = 100; // throws UnsupportedError
/// source.value = 100; // readOnly now contains 100
/// ```
///
/// ### Type Parameters:
/// - [V]: The type of the value contained in the cell.
/// - [C]: The specific [TissueValue] implementation type (usually `TissueValue<V>`).
abstract class UnmodifiableTissueValueBase<V, C extends TissueValue<V>>
    extends UnmodifiableTissueBase<V, ValueContainer<V>, C>
    with TissueValueMixin<V, C>
    implements UnmodifiableTissueValue<V> {
  @override
  TissueValueNucleusBase<V, C> get _nucleus =>
      super._nucleus as TissueValueNucleusBase<V, C>;

  @override
  Iterable<Function> get modifiable => <Function>{};

  /// The internal constructor that materialises a read‑only, live view of a
  /// reactive single value.
  ///
  /// ### When to use
  /// You never call this constructor directly. It is invoked by the framework
  /// when you write `myValue.unmodifiable`, or when you use one of the
  /// specialised factories (`UnmodifiableTissueValue`, `UnmodifiableTissueValue.view`,
  /// or `UnmodifiableTissueValue.fromNucleus`).
  ///
  /// You don't. This is an internal constructor. But understanding it helps
  /// you trust that `.unmodifiable` is cheap (zero‑copy), live, and deeply
  /// safe.
  ///
  /// ### How it works
  /// 1. **Logic activation**: It receives a [TissueValueNucleusBase] (the
  ///    immutable blueprint) and binds it to the new view instance. The
  ///    nucleus holds the value's structural strategy (`finalValue`), its
  ///    synchronisation [Lock], and its governance rules.
  /// 2. **State seeding**: If a [value] is provided, it writes it directly
  ///    into the underlying [ValueContainer] (the physical storage) atomically.
  ///    This is an optimisation – it seeds the container immediately without
  ///    waiting for the first read.
  /// 3. **Deep immutability (`unmodifiableElement`)**: If this flag is `true`
  ///    and the [value] is itself a [Cell], it calls `_nucleus.synapses.link`
  ///    to establish a reactive dependency. This ensures that when the inner
  ///    cell changes, this view (and its observers) receive a
  ///    [Tissue.elementUpdated] pulse.
  /// 4. **Lazy container resolution**: The container is resolved via a helper
  ///    (`get`) that walks up the principal chain if needed. This means the
  ///    view shares the same physical storage as its source – **zero‑copy**.
  ///
  /// ### Example (internal usage – how the framework creates a view)
  /// ```dart
  /// // When you write source.unmodifiable, the framework does something like:
  /// final source = TissueValue<int>(42);
  /// final readOnly = UnmodifiableTissueValueBase<int, TissueValue<int>>(
  ///   source._nucleus,            // shares the same blueprint
  ///   unmodifiableElement: true,  // deep immutability on
  ///   value: source.value,        // seeds the container with the initial state
  /// );
  /// // Now readOnly shares the same storage, blocks mutations, and is live.
  /// ```
  ///
  /// ### Parameters:
  /// - [properties]: **Required**. The immutable blueprint that defines the
  ///   value's behaviour, storage strategy (`finalValue`), and governance.
  /// - [unmodifiableElement]: If `true`, and the value is a [Cell], it is
  ///   projected as its `.unmodifiable` deputy when accessed. Defaults to
  ///   `true` in most factories.
  /// - [value]: Optional initial value to seed the physical container.
  ///   This is typically the source's current value.
  UnmodifiableTissueValueBase(super.properties,
      {super.unmodifiableElement, V? value})
      : super() {
    final container =
        get<Container?>(() => _nucleus.record.local.container, orElse: null);
    if (container != null) {
      _nucleus.container.store.value = value;
    }
    if (unmodifiableElement) {
      final bind = get<Cell?>(() => _nucleus.record.local.bind, orElse: null);
      if (bind != null && value != null) {
        if (value is Cell) {
          _nucleus.synapses.link(value, downstreamCell: this);
        }
      }
    }
  }

  /// Returns this instance, as it is already unmodifiable.
  @override
  TissueValue<V> get unmodifiable => this;

  /// Returns the validation rule currently applied to this value.
  @override
  TestTissue<V, C> get validate => _nucleus.testRule;

  /// Determines whether this `UnmodifiableTissueValueBase` is equal to another `Object`.
  ///
  /// Equality is determined based on the following rules:
  /// 1.  **Identity Check**: If `identical(this, other)` is `true`, they are equal.
  /// 2.  **`TissueValue<V>` Check**: If `other` is a `TissueValue<V>`:
  ///     a.  If `other` is *not* an `Unmodifiable` instance itself:
  ///         It checks if `this` unmodifiable value is bound to `other` (i.e.,
  ///         `_nucleus.bind` is `other`). If so, it then checks if
  ///         `other.unmodifiable` is identical to `this`. This confirms that
  ///         `this` is indeed the unmodifiable view of `other`.
  ///     b.  If the above conditions are not met, it falls back to comparing their
  ///         `value` properties: `this.value != null && other.value == this.value`.
  /// 3.  **Raw Value Check**: If `other` is of type `V` and `this.value` is not `null`,
  ///     it compares `other == this.value`.
  /// 4.  **Default**: If none of the above conditions are met, they are considered
  ///     not equal.
  ///
  /// This operator provides robust equality semantics, crucial for comparing
  /// unmodifiable views with their sources or with other values.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is TissueValue<V>) {
      if (other is! Unmodifiable) {
        if (_nucleus.bind != null && identical(_nucleus.bind, other)) {
          return identical(other.unmodifiable, this);
        }
      }
      return value != null && other.value == value;
    }
    if (other is V && value != null) {
      return other == value;
    }
    return false;
  }

  /// Computes the hash code for this `UnmodifiableTissueValueBase` instance.
  ///
  /// The hash code is derived from the hash code of the underlying data container.
  /// This provides a stable hash code even if the value itself is `null`.
  ///
  /// This is consistent with the `operator==` implementation.
  @override
  int get hashCode => _nucleus.container.hashCode;
}

/// A mixin that provides the core implementation for [TissueValue] behaviors,
/// particularly for accessing and modifying the single value it holds.
///
/// This mixin is designed to be used on classes that extend [TissueBase<V>]
/// and implement [TissueValue<V>]. It encapsulates the logic for:
/// - **Value Access**: Implementing the `value` getter to retrieve the current
///   value from the underlying [ValueContainer].
/// - **Value Modification**: Implementing the `value` setter and the `set()`
///   method. These methods ensure that modifications are only allowed if the
///   instance is not `Unmodifiable`.
/// - **Core Set Logic (`_set`)**: Providing a concrete implementation of the
///   `_set` method, which handles validation (`testRule`), value update,
///   change event creation, and pulse dispatching.
/// - **Modifiable Operations**: Declaring `set` as a modifiable function,
///   allowing it to be invoked through the `apply` mechanism and be subject
///   to action rules.
/// - **Comparison Operators**: Providing default implementations for `==`,
///   `<`, `>`, and `<=` to allow direct comparison with raw values.
///
/// ### When to use
/// Only if you are building a custom value implementation that needs to reuse
/// the standard ValueCell logic.
///
/// This mixin is used internally by `TissueValueBase` and
/// `UnmodifiableTissueValueBase`. You don't interact with it directly – it
/// provides the ValueCell API for tissues.
///
/// ### How it works
/// - It requires the host class to provide `_nucleus` (a `TissueValueNucleusBase`)
///   and `validate` (a `TestTissue`).
/// - It implements the `value` getter and setter by delegating to the
///   [ValueContainer].
/// - The `set` method routes the mutation through the `apply` gateway, which
///   validates the action and calls the private `_set` method.
/// - `_set` updates the container, manages links (if the value is a [Cell]),
///   and dispatches a [Tissue.elementUpdated] via the receptor.
///
mixin TissueValueMixin<V, C extends TissueValue<V>>
// on TissueBase<V,TissueValue<V>,C>
    implements
        TissueValue<V> {
  @override
  TissueValueNucleusBase<V, C> get _nucleus;

  @override
  Iterable<Function> get modifiable => <Function>{
        set,
        // ...super.modifiable
      };

  /// The value of this TissueValue
  @override
  V? get value => _nucleus.container.store.value;

  /// Sets the value of this TissueValue
  @override
  set value(V? value) {
    if (this is! Unmodifiable) {
      set(value);
    }
  }

  /// Sets the current value and returns `true` if successful.
  ///
  /// This is the recommended way to mutate a [TissueValue] imperatively.
  /// It returns `false` if the value was rejected by validation, or if it
  /// was identical to the current value.
  ///
  /// ### Example
  /// ```dart
  /// final counter = TissueValue<int>(0);
  /// if (counter.set(42)) {
  ///   print('Value updated to 42');
  /// }
  /// ```
  @override
  bool set(V? value) {
    if (this is! Unmodifiable) {
      return _set(value) != null;
    }
    return false;
  }

  /// Internal method that performs the actual mutation and event creation.
  ///
  /// This method is called by `apply` after validation. It updates the
  /// underlying container, manages links (if the value is a [Cell]), and
  /// creates a [Tissue.elementUpdated].
  ///
  /// ### Parameters:
  /// - [v]: The new value.
  /// - [notification]: If `false`, the event is created but not dispatched.
  /// - [deputy]: The tissue that initiated the change (used for source tracking).
  ///
  /// ### Returns:
  /// The [Tissue.elementUpdated] if the value was changed, or `null` otherwise.
  @override
  TissuePulse<ElementUpdatedRecord<V, TissueValue<V>>>? _set(V? v,
      {bool notification = true, Tissue<V>? deputy}) {
    if (this is Unmodifiable) {
      return null;
    }
    TissuePulse<ElementUpdatedRecord<V, TissueValue<V>>>? event;

    if (validate.action(set,
            host: this,
            arguments: (positionalArguments: [v], namedArguments: null)) ==
        true) {
      if (validate.element(v, host: this, action: set) == true) {
        final before = value;

        if (_nucleus.container.store.value != v) {
          _nucleus.container.store.value = v;

          if (before is Cell) {
            _nucleus.synapses.unlink(before, downstreamCell: this);
          }
          if (v is Cell) {
            _nucleus.synapses.link(v, downstreamCell: this);
          }

          event = _TissuePulse<ElementUpdatedRecord<V, TissueValue<V>>>(
              source: deputy ?? this,
              payload: (value: (deputy ?? this) as C, before: before, after: v),
              type: Tissue.elementUpdated);
          if (notification) {
            _nucleus.receptor(event);
          }
        }
      }
    }

    return event;
  }

  /// The mutation dispatch engine for value tissues.
  ///
  /// Routes whitelisted mutation functions (`set`) through the integrity
  /// gate and the private `_set` implementation; other functions execute
  /// directly, mirroring the retired dynamic gateway.
  dynamic dispatch(
    Function function, {
    List? positionalArguments,
    Map<Symbol, dynamic>? namedArguments,
  }) {
    // Aligned with the other tissue mixins: only whitelisted functions
    // execute. Unmodifiable views expose an empty whitelist, so unknown
    // functions are rejected instead of running unvetted.
    if (modifiable.contains(function)) {
      try {
        if (validate.action(function, host: this, arguments: (
              positionalArguments: positionalArguments,
              namedArguments: namedArguments
            )) ==
            true) {
          final notification = namedArguments?[#$notification] ?? true;
          final deputy = namedArguments?[#deputy];

          if (function == set) {
            return Function.apply(_set, positionalArguments,
                {#notification: notification, #deputy: deputy});
          }
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is V) {
      return other == value;
    }
    if (other is TissueValue<V>) {
      return other.value == value;
    }
    return false;
  }

  /// Comparison operators for numeric values
  @override
  bool operator <=(Object other) {
    bool compare(V v) {
      if (v is num) {
        return (value as num) <= v;
      }
      return false;
    }

    if (value != null) {
      if (other is TissueValue<V> && other.value != null) {
        return compare(other.value as V);
      } else if (V == dynamic || other is V) {
        return compare(other as V);
      }
    }

    return false;
  }

  /// Comparison operators for numeric values
  @override
  bool operator >(Object other) {
    bool compare(V v) {
      if (v is num) {
        return (value as num) > v;
      }
      return false;
    }

    if (value != null) {
      if (other is TissueValue<V> && other.value != null) {
        return compare(other.value as V);
      } else if (V == dynamic || other is V) {
        return compare(other as V);
      }
    }

    return false;
  }

  /// Comparison operators for numeric values
  @override
  bool operator <(Object other) {
    bool compare(V v) {
      if (v is num) {
        return (value as num) < v;
      }
      return false;
    }

    if (value != null) {
      if (other is TissueValue<V> && other.value != null) {
        return compare(other.value as V);
      } else if (V == dynamic || other is V) {
        return compare(other as V);
      }
    }

    return false;
  }

  @override
  int get hashCode => identityHashCode(this);

  @override
  String toString() => value.toString();
}

/// An asynchronous facade for performing reactive mutation operations on a [TissueValue].
///
/// `ModifiableValueAsync` provides a [Future]‑based API that mirrors the standard
/// mutation methods of a [TissueValue]. This class is essential for scenarios
/// where value modifications need to be offloaded to the event loop or handled
/// within an `async/await` workflow.
///
/// ### When to use
/// - You are in an `async` context (e.g., a network callback) and need to
///   wait for the mutation to be fully processed.
/// - You want to avoid blocking the UI thread during a batch of updates.
/// - The mutation involves I/O or other asynchronous side‑effects.
/// - You need to know whether the mutation succeeded (`true`/`false`).
///
/// You never construct this directly. It is returned by the `async` getter
/// on any [TissueValue] (e.g., `myValue.async`). Use it when you need to
/// perform asynchronous mutations.
///
/// ### How it works
/// - It wraps the synchronous `set` method in a `Future`.
/// - The operation is scheduled through the tissue's lock, ensuring atomicity.
/// - The returned `Future` completes when the mutation has been validated,
///   applied, and propagated through the reactive graph.
///
/// ### Example
/// ```dart
/// final value = TissueValue<int>(0);
/// final success = await value.async.set(42);
/// print(success ? 'Value updated' : 'Update rejected');
/// ```
///
/// ### Type Parameters:
/// - [V]: The type of the value contained within the cell.
///
/// See also:
/// - [TissueValue.async] – the typical way to access an instance of this class.
/// - [TissueModifiableAsync] – the base class providing common async wrapping.
class ModifiableValueAsync<V> extends TissueModifiableAsync<V, TissueValue<V>> {
  /// Creates an asynchronous callable wrapper for a [TissueValue].
  ///
  /// This constructor is typically not called directly. Instead, instances are
  /// accessed via the [TissueValue.async] getter.
  ///
  /// ### Parameters:
  ///   - `tissue`: The [TissueValue<V>] whose operations will be wrapped.
  const ModifiableValueAsync(super.tissue);

  /// Asynchronously sets the value of the associated [TissueValue].
  ///
  /// This method wraps the synchronous `_tissue.set(value)` operation in a
  /// `Future`. This allows any asynchronous validation or receptor logic within
  /// the `set` process to complete before the returned `Future` resolves.
  ///
  /// The operation proceeds only if the underlying tissue is not `Unmodifiable`.
  /// If it is unmodifiable, the `Future` resolves to `false`.
  ///
  /// ### Parameters:
  ///   - `value`: The new value to attempt to set.
  ///
  /// ### Returns:
  ///   A `Future<bool>` that completes with `true` if the value was successfully
  ///   set and changed, and `false` otherwise (including if the tissue is
  ///   unmodifiable or the value was rejected by validation).
  Future<bool> set(V? value) async {
    return Future<bool>(() {
      if (this is! Unmodifiable) {
        return _tissue._set(value) != null;
      }
      return false;
    });
  }
}

/// Internal implementation of an unmodifiable async value wrapper that throws
/// on any mutation.
class _UnmodifiableModifiableValueAsync<V> implements ValueCellAsync<V> {
  final TissueValue<V> _tissue;

  const _UnmodifiableModifiableValueAsync(this._tissue);

  /// The read-only async projection has no command surface.
  @override
  Future<ApplyOutcome<R>> apply<R>(ApplyCommand command,
          {ApplyTransactionScope? tx}) =>
      Future<ApplyOutcome<R>>.error(UnsupportedError('Unmodifiable operation'));

  Future<bool> set(V? value) async {
    return Future.error(UnsupportedError('Unmodifiable operation'));
  }

  Future<V?> get value {
    final lock = _tissue._nucleus.lock;
    if (lock != null) {
      return lock.synchronized(() {
        return _tissue.value;
      });
    }
    return Future<V?>.value(_tissue.value);
  }

  @override
  Future<V?> get state => throw UnimplementedError();
}
