// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

// ignore_for_file: unused_element
// ignore_for_file: unused_field
// ignore_for_file: prefer_final_fields

/// A specialised architectural configuration interface that defines the behavioural
/// DNA, security protocols, and reactive strategies for a [TissueValue].
///
/// [TissueValueNucleus] serves as the **Stateless Blueprint** (the "Blueprint
/// Pattern") for reactive single‑value containers within the `cell_tissue`
/// ecosystem. It separates the collection's governance (how it behaves, validates,
/// and signals) from its physical state (the actual data held in memory),
/// enabling high‑fidelity state management with minimal heap overhead.
///
/// ### When to use
/// You might reference this type when you need to:
/// - Pass a pre‑configured nucleus to [TissueValue.fromNucleus] to reuse a
///   validated value blueprint.
/// - Extend a custom value implementation that needs to override the default
///   behaviour.
/// - Debug why a value is behaving in a certain way – inspect its nucleus to see
///   the `finalValue`, `testRule`, etc.
///
/// You never implement this interface directly. It is used internally by the
/// framework to configure a [TissueValue]. You interact with it indirectly when
/// creating a value cell via [TissueValue] or [TissueValue.create].
///
/// The most common way to get a nucleus is to let the framework create one for
/// you when you use `TissueValue()`. You rarely need to construct one manually.
///
/// ### How it works
/// - The nucleus holds all **stateless** configuration: the [receptor]
///   (how mutation commands are processed), the [testRule] (validation logic),
///   the [context] (security tier), and the [synapses] (propagation behaviour).
/// - It also determines the **physical storage strategy** via [containerType]
///   (mutable [Container.value] vs write‑once [Container.finalValue]).
/// - A nucleus can be **evolved** (via the `evolve` factory) to create a
///   deputy – a restricted view that shares the same data but applies different
///   rules or context.
/// - The nucleus is immutable; once created, it cannot be changed. Any
///   variation requires creating a new nucleus (or deputy).
///
/// ### Non‑obvious
/// - The [finalValue] flag is **structural**: it is fixed at creation and
///   inherited by all deputies. You cannot change a mutable value into a
///   write‑once value through a deputy.
/// - The nucleus is a **flyweight** – many value cells can share the same
///   nucleus without duplicating memory.
/// - The [clone] getter creates a fresh copy of the nucleus with its own
///   [Lock] and [Synapses]. This is used internally when you create a new
///   value from an already‑activated nucleus to avoid sharing locks.
/// - The `principal` chain allows hierarchical inheritance – a deputy nucleus
///   can override only specific properties (like `testRule`) while inheriting
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
/// * [V]: The type of the value managed by the associated [TissueValue].
///
/// See also:
/// - [TissueValue] – the reactive value instance governed by this nucleus.
/// - [TissueReceptor] – the engine that processes mutation signals.
/// - [TestTissue] – the validation logic for the value.
abstract interface class TissueValueNucleus<V> implements TissueNucleus<V> {

  /// Creates a standard, memory‑optimised implementation of [TissueValueNucleus].
  ///
  /// This factory serves as the primary entry point for configuring the identity,
  /// storage strategy, and operational logic of a [TissueValue]. It produces a
  /// stateless "Template" property set that encapsulates the rules governing how
  /// a single reactive value processes signals and validates its state transitions.
  ///
  /// ### When to use
  /// Use this when you are building a custom value configuration from scratch.
  /// For most use cases, the simpler [TissueValue] factory is sufficient.
  ///
  /// ### How it works
  /// - You provide the [finalValue] flag (default false) and optional governance
  ///   parameters.
  /// - The framework creates a nucleus record that stores only non‑default
  ///   properties (memory optimisation).
  /// - The resulting nucleus can be used to instantiate multiple value cells
  ///   that share the same logic but hold separate data.
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
  /// - [bind]: Optional upstream [Cell] to observe.
  /// - [context]: Operational environment (default: [Context.system]).
  /// - [receptor]: Mutation command processor (default: pass‑through).
  /// - [testRule]: Validation gatekeeper (default: allow all).
  /// - [synapses]: Propagation configuration (default: enabled).
  /// - [finalValue]: Whether the value can be set only once (default: false).
  /// - [user]: Optional metadata for custom logic.
  ///
  /// ### Returns:
  /// A concrete [TissueValueNucleus<V>] instance strictly configured
  /// according to the provided reactive blueprint.
  factory TissueValueNucleus({
    Cell? bind,
    Context context,
    TissueReceptor<V,TissueValue<V>> receptor,
    TestTissue<V,TissueValue<V>> testRule,
    Synapses synapses,
    bool finalValue,
    Record? user
  }) = _TissueValueNucleus<V,TissueValue<V>>;

  /// Creates a specialised extension of [TissueValueNucleus] to support
  /// hierarchical property inheritance and the **Deputy Pattern** for reactive values.
  ///
  /// This factory constructor implements the framework's **Property Cascading**
  /// architecture. It allows a "child" property set—such as a specialised view,
  /// a restricted proxy, or a localised projection—to derive its core structural
  /// configuration (including its physical [ValueContainer] storage) from a
  /// [principal], while layering on its own specific behavioural overrides.
  ///
  /// ### When to use
  /// This is the engine behind the `deputy()` method on [TissueValue]. You
  /// rarely call it directly. Use it when you need a restricted view of a value
  /// that shares the same storage but applies different validation or context.
  ///
  /// ### How it works
  /// - The new nucleus inherits all properties from [principal] unless
  ///   explicitly overridden.
  /// - You can override the [testRule] (to narrow permissions), [context] (to
  ///   change authority), [receptor] (to transform mutations), or [synapses].
  /// - The [finalValue] status is always inherited and cannot be changed.
  /// - The new nucleus shares the same [Lock] and physical storage as the
  ///   principal (unless you provide an [override] that introduces a new lock).
  ///
  /// ### Non‑obvious
  /// - The [override] parameter allows you to layer a complete pre‑configured
  ///   nucleus on top of the principal. This is useful for composing complex
  ///   deputies.
  /// - The resulting nucleus does **not** copy the principal's data – it shares
  ///   it via the inheritance chain.
  /// - If you override the [synapses], the deputy gets its own observer
  ///   registry, so listeners attached to the deputy are separate from those
  ///   attached to the principal.
  ///
  /// ### Example
  /// ```dart
  /// final principal = TissueValueNucleus.create<int>();
  /// final readOnlyNucleus = TissueValueNucleus.evolve(
  ///   principal: principal,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyValue = TissueValue.fromNucleus(readOnlyNucleus);
  /// ```
  ///
  /// ### Parameters:
  /// - [principal]: **Required**. The base nucleus to extend.
  /// - [override]: Optional. A complete nucleus whose properties are layered
  ///   on top of the principal.
  /// - [bind]: Optional override for the upstream cell.
  /// - [context]: Optional override for the execution context.
  /// - [receptor]: Optional override for the mutation processor.
  /// - [testRule]: Optional override for the validation rule.
  /// - [synapses]: Optional override for propagation behaviour.
  ///
  /// ### Returns:
  /// A new [TissueValueNucleus<V>] instance that acts as a specialised
  /// behavioral layer over the [principal].
  factory TissueValueNucleus.evolve({
    Cell? bind,
    Context? context,
    TissueReceptor<V, TissueValue<V>>? receptor,
    TestTissue<V, TissueValue<V>>? testRule,
    Synapses? synapses,

    TissueValueNucleus<V>? override,
    required TissueValueNucleus<V> principal
  }) = _TissueValueNucleus<V,TissueValue<V>>.evolve;

  /// A highly configurable static utility factory for creating specialised,
  /// type‑safe property configurations for [TissueValue] types.
  ///
  /// This method serves as the primary architectural entry point for defining
  /// the behavioural and structural blueprint of single‑value reactive nodes.
  /// It allows for precise control over the value type [V] and the public
  /// interface [C], ensuring that all logic components remain strictly
  /// type‑aligned.
  ///
  /// ### When to use
  /// Use this when you are building a custom value implementation that extends
  /// [TissueValue] and you want to ensure type safety between the value and its
  /// receptor/testRule.
  ///
  /// ### How it works
  /// - It creates a nucleus with the provided parameters, inferring defaults
  ///   where omitted.
  /// - If a [principal] is provided, it creates an evolved nucleus that
  ///   inherits from that principal.
  /// - The [container] parameter determines the storage strategy (mutable
  ///   [Container.value] or write‑once [Container.finalValue]).
  ///
  /// ### Non‑obvious
  /// - The [forceLock] flag, when `true`, allows sharing the principal's lock.
  ///   This is typically used for deputies to maintain a single atomic boundary.
  /// - The [container] parameter can be used to explicitly set the storage
  ///   strategy – useful for custom container types.
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream cell.
  /// - [context]: Optional execution context.
  /// - [receptor]: Optional mutation processor.
  /// - [testRule]: Optional validation rule.
  /// - [synapses]: Optional propagation configuration.
  /// - [container]: Optional storage strategy (e.g., `Container.value` or
  ///   `Container.finalValue`).
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns:
  /// A nucleus instance strictly configured for the specified value and
  /// tissue types.
  static TissueValueNucleusBase<V,C> create<V,C extends TissueValue<V>>({
    Cell? bind,
    Context? context,
    TissueReceptor<V,C>? receptor,
    TestTissue<V,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueValueNucleusBase<V,C>? principal
  }) {

    if (principal != null) {
      final local = TissueNucleusBase.local<V,ValueContainer<V>,C>(
        container: container,
        bind: bind, context: context, receptor: receptor, testRule: testRule, synapses: synapses, forceLock: forceLock, user: user,
      );
      return _TissueValueNucleus<V,C>.fromRecord(
          (mask: local, principal: principal)
      );
    }

    return _TissueValueNucleus<V,C>(
        bind: bind,
        context: context ?? Context.system,
        receptor: receptor ?? TissueReceptor.passThrough,
        testRule: testRule ?? TestTissue.allowAll,
        synapses: synapses ?? Synapses.enabled,
        finalValue: container == Container.finalValue,
        user: user,
        forceLock: forceLock
    );

  }

  /// Creates an independent, decoupled clone of the current [TissueValueNucleus]
  /// template.
  ///
  /// This getter implements the **Prototype Pattern** specifically for reactive
  /// single‑value configurations. It generates a peer instance that replicates the
  /// behavioural logic and structural constraints (such as the [finalValue] status
  /// resolved via [containerType]) of the original without sharing its internal
  /// lifecycle state, observer registry, or synchronisation primitives.
  ///
  /// ### When to use
  /// You rarely need to call this directly. It is used internally when a nucleus
  /// needs to be cloned to avoid sharing locks between independent values.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a value instance.
  ///
  /// ### Non‑obvious
  /// - The clone does **not** share the same `principal` – it is a root nucleus
  ///   (no parent). This means it does not inherit from the original.
  /// - Cloning is a zero‑copy operation for the logic – the logic is shared
  ///   via the flyweight record, but the state (lock, synapses) is new.
  ///
  /// ### Returns:
  /// A new [TissueValueNucleus<V>] instance with identical behavioural
  /// logic and storage strategy, but an isolated lifecycle and an
  /// independent synchronisation lock.
  @override
  TissueValueNucleus<V> get clone;

  /// Retrieves the physical storage strategy ([Container]) used by the underlying
  /// reactive value.
  ///
  /// This getter identifies the specialised data structure or allocation policy
  /// (e.g., [Container.value] for mutable state or [Container.finalValue] for
  /// write‑once state) that holds the actual element [V].
  ///
  /// ### When to use
  /// Read this to understand whether the value is mutable or write‑once.
  /// This is useful for conditional logic or debugging.
  ///
  /// ### How it works
  /// - The value is resolved by walking up the principal chain if not defined
  ///   locally.
  /// - It defaults to [Container.value] if no container type is set.
  ///
  /// ### Non‑obvious
  /// - This is a **structural** property – it is fixed and cannot be changed
  ///   through a deputy. All deputies inherit the same container type.
  /// - The container type affects whether `set` succeeds after the first
  ///   assignment ([Container.finalValue] rejects subsequent writes).
  @override
  Container get containerType;

}

/// A specialised, terminal architectural interface for a **Governed Reactive
/// Value Cell**.
///
/// [TissueValue] represents the atomic unit of state within the
/// `cell_tissue` ecosystem. It converges the standard [ValueCell] contract
/// with the [Tissue] governance model, creating a state node that is
/// simultaneously a physical storage container, an observable pulse source,
/// and a governed security boundary.
///
/// ### When to use
/// Use a [TissueValue] whenever you need a single, reactive value that:
/// - Must be observable (UI updates automatically on changes).
/// - Must enforce invariants (e.g., value range, non‑null constraints).
/// - Must be shared between components with different permissions (via deputies).
/// - Must participate in the reactive graph as a first‑class cell.
/// - Needs to be write‑once (`finalValue`) or mutable.
///
/// Most of the time, you create a [TissueValue] using the [TissueValue] factory,
/// optionally providing a [testRule] for validation:
/// ```dart
/// final counter = TissueValue<int>(0);
/// final validated = TissueValue<String>(
///   testRule: TestTissue<String>((v) => v.isNotEmpty),
/// );
/// ```
///
/// ### How it works
/// - Internally, it uses a [TissueValueNucleus] to govern behaviour and a
///   [ValueContainer] for physical storage.
/// - Every mutation (e.g., `value = ...`, `set(...)`) goes through a validation
///   pipeline ([testRule]) and emits a [ValueChangedEvent].
/// - The value is thread‑safe via its internal [Lock].
/// - It can be **deputised** to create restricted views (read‑only, scoped
///   authority, etc.) that share the same storage.
/// - It supports both mutable and write‑once (`finalValue`) storage.
/// - If the value is a [Cell], it is automatically linked to the tissue,
///   enabling "bubbling" of internal changes.
///
/// ### Non‑obvious
/// - Equality (`==`) compares the underlying value, so `valueCell == 42` works.
/// - The [async] getter returns a [ValueCellAsync] for `Future`‑based
///   operations, useful for network callbacks or background tasks.
/// - The `unmodifiable` getter is **not a snapshot** – it's a live view that
///   stays in sync with the source.
/// - If `finalValue` is `true`, the value can only be set once. Subsequent
///   `set` attempts are silently ignored or return `false`.
/// - The `set` method returns `true` if the value was changed, `false` if
///   it was rejected by validation or already had the same value.
///
/// ### Example: Basic usage
/// ```dart
/// final counter = TissueValue<int>(0);
/// counter.value = 1;
/// print(counter.value); // 1
///
/// // Listen for changes
/// counter.listen((event) {
///   if (event is ValueChangeEvent<ValueChangedRecord<int>>) {
///     final record = event.payload!;
///     print('Changed from ${record.before} to ${record.after}');
///   }
/// });
/// counter.value = 42; // prints "Changed from 1 to 42"
/// ```
///
/// ### Example: Validation
/// ```dart
/// final validAge = TissueValue<int>(
///   testRule: TestTissue<int>((v) => v >= 0 && v <= 120),
/// );
/// validAge.value = 25; // allowed
/// validAge.value = 150; // rejected – no event emitted
/// ```
///
/// ### Example: Write‑once value
/// ```dart
/// final config = TissueValue<String>(
///   finalValue: true,
/// );
/// config.value = 'production'; // allowed
/// config.value = 'development'; // rejected – value already set
/// ```
///
/// ### Example: Read‑only deputy for UI
/// ```dart
/// final source = TissueValue<int>(42);
/// final uiView = source.deputy(testRule: TestTissue.readOnly);
/// // uiView can be safely passed to a widget tree
/// // Changes to source are reflected in uiView automatically
/// ```
///
/// ### Type Parameters:
/// * [V]: The type of the value held by this cell.
///
/// See also:
/// - [Tissue] – the base interface for all reactive collections.
/// - [TissueValueNucleus] – the blueprint and configuration for the value.
/// - [UnmodifiableTissueValue] – a read‑only deputy variant.
/// - [ValueChangedEvent] – the event emitted on value changes.
abstract interface class TissueValue<V> implements Tissue<V>, ValueCell<V> {

  /// Provides access to the configuration properties of this `TissueValue`.
  ///
  /// Implementations of `TissueValue` are required to expose their configuration
  /// through an instance of [TissueValueNucleus<V>]. This object holds all
  /// settings that govern the `TissueValue`'s behaviour, including:
  /// - `bind`: The [Cell] it might be bound to.
  /// - `context`: The operational [Context] (e.g., system or user context).
  /// - `receptor`: The [TissueReceptor] for processing signals.
  /// - `testRule`: The [TestTissue] rules for validating value changes.
  /// - `synapses`: The [Synapses] settings for pulse propagation.
  /// - `finalValue`: A flag indicating if the underlying value container is intended
  ///   to be immutable after the first set.
  @override
  TissueValueNucleus<V> get _nucleus;

  /// Primary architectural factory for instantiating a [TissueValue],
  /// creating a reactive, singular state node governed by the **Conactive Model**.
  ///
  /// This factory serves as the standard entry point for materialising a
  /// synchronised value cell that participates in the framework's high‑fidelity
  /// data‑flow graph. It orchestrates the relationship between the logical
  /// governance layer (the [Nucleus]) and the physical storage layer (the
  /// [Container]), ensuring that every state transition is atomic,
  /// validated, and observable.
  ///
  /// ### When to use
  /// Use this when you need a basic reactive value with default behaviour.
  /// For more control (e.g., custom storage, context, or governance), use
  /// [TissueValue.create] or [TissueValue.fromNucleus].
  ///
  /// ### How it works
  /// - You provide an optional initial [value] and optional governance parameters.
  /// - The value cell is created and automatically linked to any child cells.
  ///
  /// ### Parameters:
  /// - [value]: Optional initial value.
  /// - [bind]: Optional upstream [Cell] for reactive dependency.
  /// - [context]: Operational environment (default: [Context.system]).
  /// - [receptor]: [TissueReceptor] for processing mutations.
  /// - [testRule]: [TestTissue] for validating changes.
  /// - [synapses]: [Synapses] configuration for broadcasting.
  /// - [finalValue]: Whether the value can be set only once (default: false).
  ///
  /// ### Returns:
  /// A new [TissueValue<V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final counter = TissueValue<int>(0);
  /// ```
  factory TissueValue(V? value, {
    Cell? bind,
    Context context,
    TestTissue<V,TissueValue<V>> testRule,
    TissueReceptor<V,TissueValue<V>> receptor,
    Synapses synapses,
    bool finalValue,
  }) = _TissueValue<V,TissueValue<V>>;

  /// Architectural factory for instantiating an empty, reactive [TissueValue]
  /// governed by the **Conactive Model**.
  ///
  /// This constructor is the preferred entry point for materialising a singular
  /// state node that begins its lifecycle without a defined value (`null`) but
  /// requires full integration into the `cell` framework's reactive graph. It
  /// facilitates the creation of a "Hot" state node—ready to observe, validate,
  /// and synchronise future mutations.
  ///
  /// ### When to use
  /// Use this when you need an empty value that will be populated later.
  ///
  /// ### How it works
  /// - It creates an empty value cell with the provided governance parameters.
  /// - The cell is fully integrated into the reactive graph.
  ///
  /// ### Parameters:
  /// - [bind], [context], [receptor], [testRule], [synapses] as in the
  ///   default constructor.
  ///
  /// ### Returns:
  /// A new, empty [TissueValue<V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final emptyValue = TissueValue.empty<int>();
  /// ```
  factory TissueValue.empty({
    Cell? bind,
    Context context,
    TestTissue<V,TissueValue<V>> testRule,
    TissueReceptor<V,TissueValue<V>> receptor,
    Synapses synapses,
  }) = _TissueValue<V,TissueValue<V>>.empty;

  /// Primary architectural factory for materialising a [TissueValue] from
  /// an existing [TissueValueNucleus] (the "Reactive DNA").
  ///
  /// This constructor is the preferred entry point for the **Blueprint‑First
  /// Initialisation** pattern. It decouples the definition of the value's
  /// governance—including its security rules, operational context, and
  /// command processing—from the instantiation of the reactive node itself.
  ///
  /// ### When to use
  /// - You have a reusable nucleus (e.g., a "ValidatedConfig" blueprint).
  /// - You are building a custom value implementation that needs a specific
  ///   nucleus configuration.
  /// - You are restoring a value from a serialised state where the nucleus is
  ///   already constructed.
  ///
  /// ### How it works
  /// - The value adopts the nucleus's rules, context, and receptor.
  /// - If [value] is provided, it is ingested atomically and validated
  ///   against the nucleus's [testRule].
  ///
  /// ### Example
  /// ```dart
  /// final nucleus = TissueValueNucleus.create<int>(
  ///   testRule: TestTissue<int>((v) => v >= 0),
  ///   finalValue: true,
  /// );
  /// final value = TissueValue.fromNucleus(nucleus, value: 42);
  /// ```
  ///
  /// ### Parameters:
  /// - [nucleus]: The blueprint to use.
  /// - [value]: Optional initial data.
  ///
  /// ### Returns:
  /// A concrete [TissueValue<V>] instance.
  factory TissueValue.fromNucleus(TissueValueNucleus<V> nucleus, {V? value})
  = _TissueValue<V,TissueValue<V>>.fromNucleus;

  /// A high‑fidelity architectural factory for creating a **Deeply
  /// Immodifiable Reactive View** (Deputy) of an existing [TissueValue].
  ///
  /// This constructor is the low‑level version of the `.unmodifiable` getter.
  /// You almost never call it directly – use `value.unmodifiable` instead.
  ///
  /// ### When to use
  /// Use this when you need to share a value with code that should only read
  /// data, never write it. For example, passing a value to a UI widget.
  ///
  /// ### How it works
  /// - It creates a read‑only deputy that shares the same storage and lock as
  ///   the [bind] source.
  /// - It applies `TestTissue.readOnly` and optionally projects child cells.
  /// - The view is live and stays in sync with the source.
  ///
  /// ### Parameters
  /// - [bind]: The source value to mirror.
  ///
  /// ### Returns:
  /// A read‑only [TissueValue<V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueValue<int>(42);
  /// final readOnly = TissueValue.unmodifiable(source);
  /// // readOnly.value = 100; // blocked
  /// source.value = 100; // readOnly reflects the change
  /// ```
  factory TissueValue.unmodifiable(TissueValue<V> bind)
  = _UnmodifiableTissueValue<V,TissueValue<V>>.view;

  /// A high‑level architectural factory for creating a specialised, type‑safe
  /// reactive value with explicit control over its behavioural and structural blueprint.
  ///
  /// This static method serves as a primary entry point for constructing
  /// [TissueValue] instances that require deep customisation. It streamlines
  /// the process by simultaneously defining the value's configuration (its "DNA")
  /// and initialising the reactive node within the data‑flow graph.
  ///
  /// ### When to use
  /// Use this when the simple [TissueValue] factory is insufficient, and you
  /// need to:
  /// - Specify a custom storage strategy ([container]).
  /// - Provide a custom [receptor] or [testRule] with full type safety.
  /// - Extend an existing nucleus via [principal].
  ///
  /// ### How it works
  /// - It builds a nucleus using [TissueValueNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the value from that nucleus, optionally ingesting
  ///   an initial [value].
  /// - The [principal] parameter allows you to inherit configuration from an
  ///   existing nucleus, enabling the deputy pattern at the nucleus level.
  ///
  /// ### Parameters
  /// - [value]: Optional initial data.
  /// - [bind]: Optional upstream cell.
  /// - [context]: Optional execution context.
  /// - [receptor]: Optional mutation processor.
  /// - [testRule]: Optional validation rule.
  /// - [synapses]: Optional propagation configuration.
  /// - [container]: Optional storage strategy (e.g., `Container.value` or
  ///   `Container.finalValue`).
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns:
  /// A concrete [TissueValueBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final value = TissueValue.create<int, TissueValue<int>>(
  ///   container: Container.finalValue,
  ///   value: 42,
  ///   testRule: TestTissue<int>((v) => v > 0),
  /// );
  /// ```
  static TissueValueBase<V,C> create<V,C extends TissueValue<V>>({
    V? value,

    Cell? bind,
    Context? context,
    TissueReceptor<V,C>? receptor,
    TestTissue<V,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueValueNucleusBase<V,C>? principal
  }) {
    final properties = TissueValueNucleus.create<V,C>(
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
    return _TissueValue<V,C>.fromNucleus(properties, value: value);

  }

  /// Creates a "Deputy" projection of this value—a specialised proxy that
  /// shares the same physical data but operates under unique behavioural rules.
  ///
  /// The [deputy] method is the primary engine for **Security Scoping** and
  /// **Behavioural Specialisation** within the `cell_tissue` value ecosystem.
  /// It implements the **Deputy Pattern**, allowing a single "Principal"
  /// [TissueValue] to be viewed or modified through multiple restricted
  /// or specialised lenses without duplicating the underlying storage.
  ///
  /// ### When to use
  /// Use this when you need a restricted view of the value:
  /// - Read‑only view: `value.deputy(testRule: TestTissue.readOnly)`
  /// - Scoped authority: `value.deputy(context: DeputyContext.delegate(...))`
  /// - Temporary access: `value.deputy(ephemeralPolicy: ...)`
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
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueValue<int>(42);
  /// final readOnly = await source.deputy(testRule: TestTissue.readOnly);
  /// // readOnly.value = 100; // blocked
  /// source.value = 100; // readOnly reflects the change
  /// ```
  @override
  FutureOr<TissueValue<V>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  /// Returns the current payload held within this reactive value container.
  ///
  /// The [value] getter is the primary observational entry point for a
  /// [TissueValue]. In the `cell_tissue` architecture, this is
  /// more than a simple field access; it represents the resolution of the
  /// **Current Source of Truth** from the underlying [TissueContainer].
  ///
  /// ### When to use
  /// This is the standard way to read the value synchronously.
  ///
  /// ### How it works
  /// - It queries the [ValueContainer] (the physical storage strategy) to
  ///   retrieve the data.
  /// - For [UnmodifiableTissueValue], if the value is a [Cell], it returns
  ///   the `.unmodifiable` projection.
  /// - It is a non‑triggering observation – it does not initiate a
  ///   propagation wave.
  ///
  /// ### Returns:
  /// The current state of type [V] or `null` if the container is empty.
  @override
  V? get value;

  /// Sets the current payload of this reactive value container, triggering a
  /// managed propagation wave if the state evolves.
  ///
  /// Assigning a new value via the [value] setter is a **Transactional Reactive
  /// Operation**. In the `cell_tissue` ecosystem, this setter acts as the
  /// high‑level entry point for the **Conactive Model**, orchestrating validation,
  /// physical storage update, and pulse broadcasting in a single atomic cycle.
  ///
  /// ### When to use
  /// This is the standard way to update the value synchronously.
  ///
  /// ### How it works
  /// - The operation enters the host [Nucleus]'s synchronisation [Lock].
  /// - The `newValue` is submitted to the [TestTissue] ruleset.
  /// - If the value is valid and different, it is written to the [ValueContainer].
  /// - If the value is a [Cell], the framework manages the synapse wiring.
  /// - A [ValueChangedEvent] is dispatched to observers.
  ///
  /// ### Non‑obvious
  /// - If the new value is identical to the current value (by `==`), the
  ///   operation short‑circuits and no event is emitted.
  /// - On a deputy, this setter applies the deputy's specific [testRule] stack.
  /// - On an unmodifiable projection, this setter throws [UnsupportedError].
  ///
  /// ### Example
  /// ```dart
  /// final counter = TissueValue<int>(0);
  /// counter.value = 42;
  /// ```
  set value(V? value);

  /// Attempts to update the current payload, returning a boolean indicating
  /// whether the state transition was successfully committed.
  ///
  /// While the [value] setter provides a standard property‑style interface,
  /// the [set] method is the primary **Imperative Mutation Handle** for
  /// [TissueValue]. It performs the same comprehensive reactive sequence—
  /// including synchronisation, validation, and pulse propagation—but provides
  /// explicit boolean feedback to the caller regarding the outcome of the
  /// operation.
  ///
  /// ### When to use
  /// Use this when you need to know whether the mutation succeeded, e.g., for
  /// conditional logic or error handling.
  ///
  /// ### How it works
  /// - It follows the same pipeline as the [value] setter.
  /// - Returns `true` if the value was valid, different, and successfully
  ///   committed.
  /// - Returns `false` if the value was rejected by validation or identical
  ///   to the current value.
  ///
  /// ### Example
  /// ```dart
  /// final counter = TissueValue<int>(0);
  /// if (counter.set(42)) {
  ///   print('Value updated successfully');
  /// } else {
  ///   print('Value was rejected or unchanged');
  /// }
  /// ```
  ///
  /// ### Returns:
  /// - `true`: The value was successfully committed.
  /// - `false`: The operation was rejected or was a no‑op.
  bool set(V? value);

  // ignore: unused_element_parameter (notification and deputy are used by implementations)
  ValueChangedEvent? _set(V? v, {bool notification = true, Tissue<V>? deputy});

  /// Returns a read‑only, reactive projection (Deputy) of this [TissueValue].
  ///
  /// This property provides a safe, immutable interface to the single value
  /// managed by this container while maintaining a live, synchronised
  /// connection to the underlying source of truth. In the `cell_tissue`
  /// ecosystem, it is the primary mechanism for implementing **Deep
  /// Immutability** and security‑scoped access control.
  ///
  /// ### When to use
  /// Use this when you need to share the value with components that should
  /// observe changes but never mutate it – e.g., UI widgets, loggers.
  ///
  /// ### How it works
  /// - Shares the same physical storage and lock as the source.
  /// - Applies `TestTissue.readOnly` – all mutations are blocked.
  /// - The view is **live** – changes to the source are immediately reflected.
  /// - If the source contains a child [Cell], it is projected as read‑only.
  ///
  /// ### Returns
  /// A read‑only [TissueValue<V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueValue<int>(42);
  /// final readOnly = source.unmodifiable;
  /// // readOnly.value = 100; // blocked
  /// source.value = 100;
  /// print(readOnly.value); // 100 (live update)
  /// ```
  @override
  TissueValue<V> get unmodifiable;

  /// Provides an asynchronous interface for performing mutation operations.
  ///
  /// The [async] getter returns a [ValueCellAsync] object. This allows
  /// you to perform value operations (like `set`) and `await` their
  /// completion, which includes the propagation of reactive signals.
  ///
  /// ### When to use
  /// - You are in an `async` context (e.g., a network callback) and need to
  ///   wait for the mutation to be fully processed.
  /// - You want to avoid blocking the UI thread.
  ///
  /// ### Example
  /// ```dart
  /// final counter = TissueValue<int>(0);
  /// await counter.async.set(42);
  /// ```
  @override
  ValueCellAsync<V> get async;

  /// Comparison operators for objects
  @override
  // ignore: hash_and_equals
  bool operator ==(Object other);

  /// Comparison operators for numeric values
  bool operator <=(Object other);

  /// Comparison operators for numeric values
  bool operator >(Object other);

  /// Comparison operators for numeric values
  bool operator <(Object other);

}

/// A specialised, terminal architectural interface for a **Deeply Immodifiable
/// Reactive Value Cell**.
///
/// [UnmodifiableTissueValue] represents a "Security Shadow" or "Read‑Only
/// Lens" within the `cell_tissue` ecosystem. It adheres to the full
/// [TissueValue] contract but structurally and logically prohibits all
/// state‑altering operations (e.g., direct assignment to `.value` or
/// invoking `.set()`).
///
/// ### When to use
/// Use an unmodifiable value when you need to share a value with a component
/// that should **observe** changes but **never** initiate them. Common
/// scenarios include:
/// - Passing a value to a UI widget that only renders data.
/// - Exposing internal state to a logger or analytics module.
/// - Providing a safe view to a plugin or sandboxed code.
/// - Implementing a "read‑only" API for external consumers.
///
/// You never implement this interface directly. You obtain an instance by
/// calling the `.unmodifiable` getter on a [TissueValue]:
/// ```dart
/// final source = TissueValue<int>(42);
/// final readOnly = source.unmodifiable; // UnmodifiableTissueValue<int>
/// ```
///
/// ### How it works
/// - **Zero‑copy sharing**: The unmodifiable view uses the **same physical
///   storage** and **same lock** as the mutable source. No data is duplicated.
/// - **Mutation barrier**: The `modifiable` getter returns an empty set, and
///   the internal `TestTissue` policy is set to `readOnly`. Any attempt to
///   call `set`, `value =`, or `apply` with a mutation function throws an
///   [UnsupportedError] or is silently rejected.
/// - **Live reactivity**: Because it shares the same storage, changes made
///   to the source are **immediately** and **atomically** reflected in the
///   view. Observers attached to the view still receive pulses.
/// - **Deep immutability**: If `unmodifiableElement` is `true` (the default),
///   and the value is itself a [Cell], it is automatically projected as its
///   `.unmodifiable` deputy when accessed.
///
/// ### Non‑obvious
/// - **It is not a snapshot**: Unlike a constant or a final variable, this
///   view is **live**. If the source changes, the view changes with it.
/// - **Equality**: `source == source.unmodifiable` is `true` – they are
///   considered the same logical entity.
/// - **Recursive projection**: If the value is a [Cell], accessing it through
///   the unmodifiable view returns its `.unmodifiable` deputy.
/// - **Own observer registry**: The view has its own [Synapses] registry, so
///   observers attached to the view are separate from those on the source.
///
/// ### Example: Read‑only UI projection
/// ```dart
/// final source = TissueValue<String>('Hello');
/// final readOnly = source.unmodifiable;
/// // Render in a widget
/// myWidget(value: readOnly);
/// // Later, source.value = 'World';
/// // The widget automatically re‑renders because readOnly is live.
/// ```
///
/// ### Type Parameters:
/// * [V]: The type of the value held by the cell.
///
/// See also:
/// - [TissueValue] – the mutable counterpart.
/// - [UnmodifiableTissue] – the general contract for read‑only tissues.
/// - [Unmodifiable] – the marker interface for all read‑only proxies.
abstract interface class UnmodifiableTissueValue<V> implements TissueValue<V>, UnmodifiableTissue<V> {

  /// The primary architectural factory for instantiating an [UnmodifiableTissueValue],
  /// materializing a read‑only, reactive state node from an initial [value].
  ///
  /// This constructor is a fundamental component of the framework's **Security Scoping**
  /// and **Deep Immutability** architecture. It is designed to initialise a value
  /// node that conceptually represents a **Fixed Constant** or **Snapshot**
  /// that remains reactive—meaning it can be observed and synchronised across the
  /// graph—but strictly prohibits structural or state‑altering modification.
  ///
  /// ### When to use
  /// Use this when you need a standalone immutable value that is not derived
  /// from a mutable source – e.g., for configuration constants or fixed state.
  ///
  /// ### How it works
  /// - The factory creates a new value node with a read‑only nucleus.
  /// - The provided [value] is stored in a physical container that is
  ///   never modified.
  /// - If [unmodifiableElement] is `true` and the value is a [Cell], it is
  ///   projected as an unmodifiable deputy.
  /// - The value is fully reactive but blocks all mutations.
  ///
  /// ### Parameters:
  /// - [value]: The immutable data.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - [nucleus]: Optional blueprint; if omitted, a standard read‑only nucleus
  ///   is used.
  ///
  /// ### Returns:
  /// A new [UnmodifiableTissueValue<V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final fixed = UnmodifiableTissueValue<String>('production');
  /// ```
  factory UnmodifiableTissueValue(V value, {bool unmodifiableElement, TissueValueNucleus<V>? properties})
  = _UnmodifiableTissueValue<V,TissueValue<V>>;

  /// A high‑fidelity architectural factory for creating a **Deeply
  /// Immodifiable Reactive View** (Deputy) of an existing [TissueValue].
  ///
  /// This constructor is the low‑level version of the `.unmodifiable` getter.
  /// You almost never call it directly – use `value.unmodifiable` instead.
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
  /// - [bind]: The source value to mirror.
  /// - [context]: Optional override for the execution context.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  ///
  /// ### Returns:
  /// A read‑only [UnmodifiableTissueValue<V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueValue<int>(42);
  /// final readOnly = UnmodifiableTissueValue.view(source);
  /// ```
  factory UnmodifiableTissueValue.view(TissueValue<V> bind, {Context? context, bool unmodifiableElement})
  = _UnmodifiableTissueValue<V,TissueValue<V>>.view;

  /// A low‑level architectural factory for materializing an
  /// [UnmodifiableTissueValue] directly from a pre‑constructed
  /// reactive blueprint ([nucleus]).
  ///
  /// This constructor is the primary **Materialization Hook** used when the
  /// behavioural identity—including security rules, execution context, and
  /// synchronisation domain—has already been synthesised (e.g., via
  /// [TissueValueNucleus.evolve] or a custom [Deputy] derivation).
  ///
  /// ### When to use
  /// Use this when you already have a pre‑configured read‑only nucleus and want
  /// to instantiate a value from it. Typically used in advanced customisation
  /// or serialisation scenarios.
  ///
  /// ### How it works
  /// - The value adopts the nucleus's rules, context, and receptor.
  /// - If [value] is provided, it is ingested atomically.
  /// - The [unmodifiableElement] flag applies deep immutability.
  ///
  /// ### Parameters:
  /// - [nucleus]: The pre‑configured read‑only blueprint.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - [value]: Optional initial data.
  ///
  /// ### Returns:
  /// A concrete [UnmodifiableTissueValue<V>] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlyNucleus = TissueValueNucleus.evolve(
  ///   principal: myNucleus,
  ///   testRule: TestTissue.readOnly,
  /// );
  /// final readOnlyValue = UnmodifiableTissueValue.fromNucleus(readOnlyNucleus);
  /// ```
  factory UnmodifiableTissueValue.fromNucleus(TissueValueNucleus<V> properties, {bool unmodifiableElement, V? value})
  = _UnmodifiableTissueValue<V,TissueValue<V>>.fromNucleus;

  /// An advanced architectural factory for creating a specialised, type‑safe
  /// [UnmodifiableTissueValue] with granular control over its behavioural
  /// and structural identity.
  ///
  /// This static method serves as the primary entry point for constructing
  /// read‑only reactive values that require deep customisation of their
  /// reactive blueprint. It streamlines the process by simultaneously
  /// resolving the property hierarchy and initialising the node within the
  /// reactive data‑flow graph.
  ///
  /// ### When to use
  /// Use this when the simpler factories don't provide enough control – e.g.,
  /// when you need to specify a custom [container] strategy, provide a
  /// specialised [receptor], or inherit from a [principal] nucleus.
  ///
  /// ### How it works
  /// - It builds a nucleus using [TissueValueNucleus.create] with the provided
  ///   parameters.
  /// - Then it instantiates the unmodifiable value from that nucleus, optionally
  ///   ingesting a [value].
  /// - The [unmodifiableElement] flag applies deep immutability.
  ///
  /// ### Parameters
  /// - [value]: Optional initial data.
  /// - [unmodifiableElement]: If `true`, child cells are projected as
  ///   unmodifiable deputies.
  /// - [bind]: Optional upstream cell.
  /// - [context]: Optional execution context.
  /// - [receptor]: Optional mutation processor.
  /// - [testRule]: Optional validation rule.
  /// - [synapses]: Optional propagation configuration.
  /// - [container]: Optional storage strategy.
  /// - [user]: Optional metadata.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns
  /// A concrete [UnmodifiableTissueValueBase] instance.
  ///
  /// ### Example
  /// ```dart
  /// final readOnlyValue = UnmodifiableTissueValue.create<int, TissueValue<int>>(
  ///   container: Container.finalValue,
  ///   value: 42,
  ///   unmodifiableElement: true,
  /// );
  /// ```
  static UnmodifiableTissueValueBase<V,C> create<V,C extends TissueValue<V>>({
    V? value,
    bool unmodifiableElement = true,

    Cell? bind,
    Context? context,
    TissueReceptor<V,C>? receptor,
    TestTissue<V,C>? testRule,
    Synapses? synapses,

    Container? container,
    Record? user,
    forceLock = false,
    TissueValueNucleusBase<V,C>? principal,
  }) {
    return _UnmodifiableTissueValue<V,C>.fromNucleus(
        TissueValueNucleus.create<V,C>(
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
        value: value
    );
  }

  /// Provides a high‑fidelity asynchronous handle for interacting with this
  /// reactive value within the **Conactive Model**.
  ///
  /// For an [UnmodifiableTissueValue], this getter returns a specialised
  /// [ValueCellAsync] projection. While the standard [TissueValue]
  /// interface provides synchronous access, the `.async` accessor bridges
  /// the gap for non‑blocking execution domains.
  ///
  /// ### When to use
  /// Use this when you need to read the value asynchronously, e.g., from
  /// a network callback or background task.
  ///
  /// ### How it works
  /// - The async handle shares the same read‑only barrier – any mutation
  ///   attempts will fail.
  /// - Reads are synchronised via the cell's [Lock].
  ///
  /// ### Returns:
  /// A [ValueCellAsync<V>] instance that provides a strictly
  /// read‑only, asynchronous view of the reactive state.
  @override
  ValueCellAsync<V> get async;

}