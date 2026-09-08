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
class _TissueValueNucleus<V,C extends TissueValue<V>> extends TissueValueNucleusBase<V,C> {

  _TissueValueNucleus({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,

    super.forceLock,
    super.user,

    super.finalValue,
  }) : super();

  _TissueValueNucleus.evolve({
    Cell? bind,
    Context? context,
    TissueReceptor<V,C>? receptor,
    TestTissue<V,C>? testRule,
    Synapses? synapses,

    bool forceLock = true,

    TissueValueNucleus<V>? override,
    required super.principal
  }) : super.evolve(
      override: override ?? _TissueValueNucleus<V,C>.fromRecord(
          TissueNucleusBase.local<V,ValueContainer<V>,C>(
              bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock
          ))
  );

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
  TissueValueNucleusBase<V,C> get clone {
    return TissueValueNucleus.create<V,C>(
        container: containerType,
        context: context,
        receptor: receptor,
        testRule: testRule,
        synapses: synapses != Synapses.disabled ? Synapses.enabled : Synapses.disabled,
        user: user,
        forceLock: false
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
/// ### Non‑obvious
/// - The `finalValue` flag is **structural** – it is fixed at creation and
///   inherited by all deputies. A deputy cannot change a mutable value into
///   a write‑once value, or vice versa.
/// - The nucleus is a **flyweight** – many value cells can share the same
///   nucleus without duplicating memory.
/// - The [clone] getter creates a root nucleus (no principal) with its own
///   lock, making it safe to use for independent value instances.
/// - The [principal] chain enables **prototype inheritance** – a deputy can
///   override only specific properties (like `testRule`) while inheriting
///   the rest from its principal.
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

  /// **Primary Constructor** – defines the immutable behaviour and storage
  /// strategy for a reactive single value.
  ///
  /// ### When to use
  /// **Internal framework use only.** This constructor is `public` only so
  /// that concrete subclasses (like `_TissueValueNucleus`) can invoke it via
  /// `super()`. **Application code should never call this directly.**
  ///
  /// If you need a nucleus, use [TissueValueNucleus.create] to create one
  /// from scratch, or [TissueValueNucleus.evolve] to derive one from an
  /// existing principal.
  ///
  /// You are writing a custom value implementation that extends
  /// `TissueValueNucleusBase` and need to pass configuration up to the base.
  ///
  /// ### How it works
  /// 1. The [finalValue] flag determines the physical container:
  ///    - `true` → [Container.finalValue] – the value can be set only once.
  ///    - `false` → [Container.value] – the value is mutable.
  /// 2. All other parameters are passed to the super‑constructor, which
  ///    stores them in a memory‑optimised record using bitmasking.
  /// 3. The resulting nucleus is immutable – you cannot change its
  ///    configuration after creation.
  ///
  /// ### Non‑obvious
  /// - The [finalValue] flag is **structural** – once set, it cannot be
  ///   changed by a deputy. If you need both mutable and write‑once views
  ///   of the same data, you must create two separate nuclei.
  /// - The [receptor] is automatically cloned if it is already activated
  ///   (bound to another cell), ensuring that each nucleus starts with a
  ///   clean logic instance.
  /// - If [synapses] is [Synapses.enabled], a fresh, empty registry is
  ///   created for the new value. If you pass [Synapses.disabled], the value
  ///   will be terminal (no broadcasts).
  /// - The [forceLock] flag controls whether a new synchronization lock is
  ///   allocated. `false` (default) creates a new lock; `true` shares the
  ///   principal's lock (used for deputies).
  ///
  /// ### Example (Internal – how the framework uses it)
  /// ```dart
  /// class _MyCustomValueNucleus<V> extends TissueValueNucleusBase<V, TissueValue<V>> {
  ///   _MyCustomValueNucleus({super.finalValue = false, ...}) : super();
  /// }
  /// ```
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream [Cell] – the value will automatically
  ///   mirror changes from this source (deputy pattern).
  /// - [context]: Security tier and execution domain (default: [Context.system]).
  /// - [receptor]: Mutation processor – defaults to [TissueReceptor.passThrough].
  /// - [testRule]: Validation gate – defaults to [TestTissue.allowAll].
  /// - [synapses]: Distribution configuration – defaults to [Synapses.enabled].
  /// - [finalValue]: `true` for write‑once, `false` for mutable (default).
  /// - [forceLock]: If `true`, shares the principal's lock (optimisation
  ///   for deputies); if `false` (default), allocates a new lock.
  /// - [user]: Optional custom metadata (e.g., UI hints, serialisation tags).
  TissueValueNucleusBase({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    bool finalValue = false,
    super.forceLock,
    super.user
  }) : super(
      container: finalValue ? Container.finalValue : Container.value
  );

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
  /// - The record must contain all necessary fields for a value nucleus,
  ///   including the `container` (of type [ValueContainer<V>]) and a
  ///   synchronisation [Lock] (unless sharing one via a principal).
  /// - The `finalValue` status is encoded in the container type.
  /// - If the record is malformed, the resulting nucleus may behave
  ///   unpredictably – use with extreme caution.
  /// - This constructor is `const`‑friendly, enabling compile‑time
  ///   instantiation of static nuclei for zero‑cost default configurations.
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

  /// **Evolution Constructor** – creates a specialised deputy nucleus by
  /// extending an existing [principal].
  ///
  /// ### When to use
  /// This constructor is part of the **internal deputy machinery**. While it
  /// is `public`, it is intended to be called only by the framework when
  /// you invoke `deputy()` on a [TissueValue]. **Application code should use
  /// `TissueValue.deputy()` or [TissueValueNucleus.evolve] instead.**
  ///
  /// You are building a custom deputy implementation and need to control
  /// exactly how a child nucleus inherits from its principal.
  ///
  /// ### How it works
  /// 1. The [principal] provides the baseline configuration (including the
  ///    container type and finalValue flag).
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
  /// - The `finalValue` flag is **always inherited** from the principal.
  ///   You cannot change a mutable value into a write‑once value, or
  ///   vice versa, through a deputy.
  /// - If you override the [synapses], the deputy gets its own observer
  ///   registry – observers attached to the deputy are separate from
  ///   those on the principal.
  /// - The [testRule] passed here is **layered on top** of the principal's
  ///   testRule (via `+`). You can only narrow permissions, never widen.
  ///
  /// ### Example (Internal)
  /// ```dart
  /// final principal = TissueValueNucleus.create<int>(finalValue: false);
  /// final readOnlyNucleus = TissueValueNucleusBase.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyValue = TissueValue.fromNucleus(readOnlyNucleus);
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
  TissueValueNucleusBase.evolve({
    super.override,
    required TissueValueNucleus<V> super.principal
  }) : super.evolve();

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
  /// ### Non‑obvious
  /// - The type is overridden to `TissueValueNucleusBase<V, C>?` – a covariant
  ///   override that ensures you get a properly typed principal when you need
  ///   to access value‑specific methods (like `containerType`).
  /// - Even though the getter is `public`, it's intended for internal
  ///   framework use. Mutating or replacing the principal after construction
  ///   is not supported – the nucleus is immutable.
  /// - The principal chain determines the `containerType` and all other
  ///   structural properties; a deputy cannot change the mutability strategy.
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
  TissueValueNucleusBase<V,C>? get principal => super.principal as TissueValueNucleusBase<V,C>?;

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
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed at creation and
  ///   inherited by all deputies. A deputy cannot change a mutable value
  ///   into a write‑once one.
  /// - Defaults to [Container.value] if not set.
  @override
  Container get containerType {
    return get<Container>(() => record.mask.inhertiable.container, fallback: () => principal?.containerType, orElse: Container.value);
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
class _TissueValue<V,C extends TissueValue<V>> extends TissueValueBase<V,C> {

  _TissueValue(V? value, {
    Cell? bind,
    Context context = Context.system,
    TestTissue<V,C> testRule = TestTissue.allowAll,
    TissueReceptor<V,C> receptor = TissueReceptor.passThrough,
    Synapses synapses = Synapses.enabled,
    bool finalValue = false,
  }) : this.fromNucleus(_TissueValueNucleus<V,C>(
    bind: bind,
    testRule: testRule,
    receptor: receptor,
    synapses: synapses,
    finalValue: finalValue,
  ), value: value);

  _TissueValue.empty({
    Cell? bind,
    Context context = Context.system,
    TestTissue<V,C> testRule = TestTissue.allowAll,
    TissueReceptor<V,C> receptor = TissueReceptor.passThrough,
    Synapses synapses = Synapses.enabled,
    bool finalValue = false,
  }) : this.fromNucleus(_TissueValueNucleus<V,C>(
    bind: bind,
    testRule: testRule,
    receptor: receptor,
    synapses: synapses,
    finalValue: finalValue,
  ));

  _TissueValue.fromNucleus(super.properties, {super.value}) : super();

  @override
  FutureOr<TissueValue<V>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<V,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueValueDeputy<V,C>._(this, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  late final TissueValue<V> unmodifiable = _UnmodifiableTissueValue<V,C>.view(this, unmodifiableElement: true);

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
        if (other._nucleus.bind != null && identical(this, other._nucleus.bind)) {
          return identical(unmodifiable, this);
        }
      }
    }
    if (other is V && value != null ) {
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
///   3. Dispatched as a [ValueChangedEvent] to all observers.
/// - The underlying storage is a [ValueContainer<V>] (a single‑value holder).
///
/// ### Non‑obvious
/// - **The `apply` Gateway**: All mutations are funnelled through `apply`.
///   This is a security boundary – deputies override `modifiable` to return
///   an empty set, rejecting any mutation attempt.
/// - **Mutability Strategy**: The `finalValue` flag is fixed at creation.
///   A deputy cannot change a mutable value into a write‑once one.
/// - **Equality Semantics**: A [TissueValue] can be compared directly to its
///   raw value (e.g., `myValue == 42`). This is a convenience for numeric
///   and comparable types.
/// - **Member‑level bubbling**: If the value is a [Cell], it is automatically
///   linked, so internal changes trigger an update event.
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
    extends TissueBase<V,ValueContainer<V>,C>
    with TissueValueMixin<V,C>
    implements TissueValue<V> {

  @override
  TissueValueNucleusBase<V,C> get _nucleus => super._nucleus as TissueValueNucleusBase<V,C>;


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
      : super(properties as TissueValueNucleusBase<V,C>) {
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
  TestTissue<V,C> get validate => _nucleus.testRule;

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
        if (other._nucleus.bind != null && identical(this, other._nucleus.bind)) {
          return identical(unmodifiable, this);
        }
      }
    }
    if (other is V && value != null ) {
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
class _TissueValueDeputy<V,C extends TissueValue<V>> extends _TissueValue<V,C> with Deputy<TissueValue<V>> {

  _TissueValueDeputy._(TissueValueBase<V,C> bind, {Context context = Context.system, TestTissue<V,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled})
      : super.fromNucleus(_TissueValueNucleus<V,C>.evolve(
      override: _TissueValueNucleus<V,C>(
        bind: bind,
        testRule: bind._nucleus.testRule + testRule,
        synapses: bind._nucleus.synapses != Synapses.disabled ? synapses : Synapses.disabled,
      ).record, principal: bind._nucleus)
  );

  @override
  FutureOr<TissueValue<V>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<V,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueValueDeputy<V,C>._(_nucleus.bind as TissueValueBase<V,C>, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
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
class _UnmodifiableTissueValue<V, C extends TissueValue<V>> extends UnmodifiableTissueValueBase<V,C> {

  _UnmodifiableTissueValue(V value, {bool unmodifiableElement = true, TissueValueNucleus<V>? properties})
      : this.fromNucleus(
      (properties ?? TissueValueNucleus.create<V,C>()) as TissueValueNucleusBase<V,C>,
      unmodifiableElement: unmodifiableElement,
      value: value
  );

  _UnmodifiableTissueValue.view(TissueValue<V> bind, {Context? context, bool unmodifiableElement = true})
      : this.fromNucleus(TissueValueNucleus.create<V,C>(bind: bind,
      container: unmodifiableElement ? bind._nucleus.containerType : null,
      context: context,
      synapses: bind._nucleus.synapses == Synapses.disabled ? Synapses.disabled : Synapses.enabled,
      principal: bind._nucleus as TissueValueNucleusBase<V,C>
  ), unmodifiableElement: unmodifiableElement,
      value: unmodifiableElement ? bind.value is Cell ? (bind.value! as Cell).unmodifiable as V : bind.value : null
  );

  _UnmodifiableTissueValue.fromNucleus(TissueValueNucleus<V> properties, {super.unmodifiableElement, super.value})
      : super(properties as TissueValueNucleusBase<V,C>);

  @override
  FutureOr<TissueValue<V>> deputy({covariant DeputyContext context = DeputyContext.system, covariant TestTissue<V,C> testRule = TestTissue.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled}) {
    return _TissueValueDeputy<V,C>._(_nucleus.bind as TissueValueBase<V,C>, context: context, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses);
  }

  @override
  TissueValue<V> get unmodifiable => this;

  @override
  TestTissue<V,C> get validate => _nucleus.testRule;

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
/// ### Non‑obvious
/// - **It is not a snapshot**: The view is live. Changes to the mutable
///   source are instantly visible.
/// - **Equality**: `source == source.unmodifiable` is `true` – they are
///   considered the same logical entity.
/// - **Recursive projection**: If `unmodifiableElement` is `true`, and the
///   value is a [Cell], accessing it through the view returns its
///   `.unmodifiable` deputy, preventing side‑door mutations.
/// - **Own observer registry**: The view has its own [Synapses] registry,
///   so observers attached to the view are independent of those on the
///   source.
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
abstract class UnmodifiableTissueValueBase<V,C extends TissueValue<V>>
    extends UnmodifiableTissueBase<V,ValueContainer<V>,C>
    with TissueValueMixin<V,C>
    implements UnmodifiableTissueValue<V> {

  @override
  TissueValueNucleusBase<V,C> get _nucleus => super._nucleus as TissueValueNucleusBase<V,C>;

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
  ///    cell changes, this view (and its observers) receive a `ValueChangedEvent`.
  /// 4. **Lazy container resolution**: The container is resolved via a helper
  ///    (`get`) that walks up the principal chain if needed. This means the
  ///    view shares the same physical storage as its source – **zero‑copy**.
  ///
  /// ### Non‑obvious
  /// - **The value is not validated**: Because this is a read‑only projection,
  ///    the constructor assumes the value is already valid (it was validated
  ///    when it was written to the source). No `testRule` check is performed here.
  /// - **Linking the inner cell**: If the value is a [Cell] and `unmodifiableElement`
  ///    is `true`, the view links itself to that cell. This means changes to
  ///    the inner cell will bubble up to *this* view's observers, which is
  ///    the correct behaviour for a live projection.
  /// - **No pulse emission**: This constructor does **not** emit a pulse.
  ///    The view is initialized silently. Observers will only see changes
  ///    that happen *after* the view is created.
  /// - **The `value` is stored directly**: It is not projected into an
  ///    unmodifiable deputy at the storage layer. The projection happens
  ///    lazily when the `value` getter is accessed (via the mixin logic).
  /// - **The `bind` check**: The constructor checks if the nucleus has a
  ///    `bind` (a principal). If so, and the value is a [Cell], it links
  ///    to ensure the view stays in sync with the principal's child cell.
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
  UnmodifiableTissueValueBase(super.properties, {super.unmodifiableElement, V? value})
      : super() {
    final container = get<Container?>(() => _nucleus.record.mask.container, orElse: null);
    if (container != null) {
      _nucleus.container.store.value = value;
    }
    if (unmodifiableElement) {
      final bind = get<Cell?>(() => _nucleus.record.mask.bind, orElse: null);
      if (bind != null && value != null) {
        if (value is Cell) {
          _nucleus.synapses.link(value, downstreamCell: this);
        }
      }
    }
  }

  //   if (value != null) {
  //     if (value is Cell) {
  //       _nucleus.container.store.value = value.unmodifiable as V;
  //       _nucleus.synapses.link(value, downstreamPole: this);
  //     } else {
  //       _nucleus.container.store.value = value;
  //     }
  //   }
  // }

  // /// Provides access to a restricted asynchronous interface for this unmodifiable value.
  // ///
  // /// Returns a specialized [ModifiableValueAsync] implementation that ensures
  // /// any asynchronous modification attempts will fail, consistent with the
  // /// unmodifiable nature of this tissue.
  // @override
  // ModifiableValueAsync<V> get async => _UnmodifiableModifiableValueAsync(this);

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
    if (other is V && value != null ) {
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
///   and dispatches a [ValueChangedEvent] via the receptor.
///
/// ### Non‑obvious
/// - The mixin does **not** hold any state itself – all state is in the nucleus.
/// - If the host class is [Unmodifiable], the `value` setter and `set` method
///   are bypassed (the host's `modifiable` is empty), so the mutation logic
///   is never reached.
/// - The `_set` method returns a [ValueChangedEvent] or `null`; the caller
///   (usually `apply`) decides whether to dispatch it.
/// - Comparison operators (`<`, `>`, `<=`) only work for numeric values.
mixin TissueValueMixin<V, C extends TissueValue<V>>
// on TissueBase<V,TissueValue<V>,C>
implements TissueValue<V> {

  @override
  TissueValueNucleusBase<V,C> get _nucleus;

  @override
  Iterable<Function> get modifiable => <Function>{set,
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
  /// creates a [ValueChangedEvent].
  ///
  /// ### Parameters:
  /// - [v]: The new value.
  /// - [notification]: If `false`, the event is created but not dispatched.
  /// - [deputy]: The tissue that initiated the change (used for source tracking).
  ///
  /// ### Returns:
  /// The [ValueChangedEvent] if the value was changed, or `null` otherwise.
  @override
  ValueChangedEvent<V,C>? _set(V? v, {bool notification = true, Tissue<V>? deputy}) {
    ValueChangedEvent<V,C>? event;

    if (validate.action(set, host: this, arguments: (positionalArguments: [v], namedArguments: null)) == true) {
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

          event = ValueChangedEvent<V,C>._(source: deputy ?? this, payload: (value: (deputy ?? this) as C, before: before, after: v));
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

    if (modifiable.contains(function)) {
      try {
        if (validate.action(function, host: this, arguments: (positionalArguments: positionalArguments, namedArguments: namedArguments)) == true) {
          final notification = namedArguments?[#$notification] ?? true;
          final deputy = namedArguments?[#deputy];

          if (function == set) {
            return Function.apply(_set, positionalArguments, {#notification: notification, #deputy: deputy});
          }
          return;
        }} catch (_) {}
    }
    return Function.apply(function, positionalArguments, namedArguments);
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
/// ### Non‑obvious
/// - The async wrapper does **not** change the validation or reactivity – it's
///   the same pipeline as synchronous calls, just non‑blocking.
/// - If the tissue is unmodifiable, the async method will throw
///   `UnsupportedError` or return `false` (depending on implementation).
/// - The `await` ensures that all downstream observers have been notified
///   before the Future resolves.
/// - The [set] method returns `true` if the value changed, `false` otherwise.
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
class ModifiableValueAsync<V> extends TissueModifiableAsync<V,TissueValue<V>> {

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
  Future<dynamic> apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
  }) {
    // TODO: implement apply
    throw UnimplementedError();
  }

  @override
  Future<V?> get state => throw UnimplementedError();

}