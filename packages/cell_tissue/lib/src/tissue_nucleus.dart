// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

/// The comprehensive architectural blueprint and behavioural metadata interface
/// for [Tissue] instances.
///
/// [TissueNucleus] defines the "Relational DNA" and operational logic
/// for reactive collections within the `cell_tissue` ecosystem. It acts
/// as a specialised [Nucleus] that bridges the gap between
/// high‑level reactive interfaces and the low‑level physical storage
/// mechanisms required for the framework's data‑flow graph.
///
/// ### When to use
/// You typically don't create a [TissueNucleus] directly. Instead, the
/// framework creates it for you. Use the factories in this interface only when
/// you need to:
/// - Build a reusable collection blueprint (e.g., a "ValidatedUserList").
/// - Create a deputy with custom validation or context.
/// - Restore a collection from a serialised state.
///
/// You never implement this interface directly. It is used internally by the
/// framework to configure a [Tissue]. You interact with it indirectly when
/// creating a tissue via [Tissue] or [Tissue.create].
///
/// The most common way to get a nucleus is to let the framework create one for
/// you when you use a tissue factory like `TissueList()` or `TissueSet()`. You
/// rarely need to construct one manually. However, you might reference this
/// type when:
/// - Passing a pre‑configured nucleus to `Tissue.fromNucleus`.
/// - Extending a custom tissue implementation.
/// - Debugging a tissue's configuration.
///
/// ### How it works
/// - The nucleus holds all **stateless** configuration: the [receptor]
///   (how mutation commands are processed), the [testRule] (validation logic),
///   the [context] (security tier), and the [synapses] (propagation behaviour).
/// - It also determines the **physical storage strategy** via [containerType]
///   (List, Set, Map, Queue, Value).
/// - A nucleus can be **evolved** (via `evolve`) to create a deputy – a
///   restricted view that shares the same data but applies different rules.
/// - The nucleus is immutable; once created, it cannot be changed. Any
///   variation requires creating a new nucleus (or deputy).
/// - The nucleus is a **flyweight** – many tissues can share the same nucleus
///   without duplicating memory.
///
/// ### Example: Reusing a validated nucleus
/// ```dart
/// final validNucleus = TissueNucleus.create<int, List<int>, TissueList<int>>(
///   testRule: TestTissue<int>((v) => v >= 0),
///   container: Container.list,
/// );
/// final list1 = Tissue.fromNucleus(validNucleus);
/// final list2 = Tissue.fromNucleus(validNucleus); // shares logic, not data
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of elements managed by the associated [Tissue].
///
/// See also:
/// - [Tissue] – the reactive collection interface governed by these nuclei.
/// - [TissueNucleusBase] – the standard abstract implementation class.
/// - [Nucleus] – the base interface for all reactive cell configurations.
abstract interface class TissueNucleus<E> implements Nucleus {
  /// The primary architectural factory for creating a [TissueNucleus],
  /// defining the foundational "Reactive DNA" and behavioural blueprint for
  /// a [Tissue] container.
  ///
  /// This constructor is the standard entry point for initialising the
  /// governance layer of any reactive collection. It utilises the **Flyweight
  /// Record Pattern** to internalise the provided parameters into a compact,
  /// deeply immutable configuration record, ensuring minimal memory overhead
  /// even in high‑density state graphs.
  ///
  /// ### When to use
  /// Use this when you are building a custom collection configuration from
  /// scratch. For most use cases, the simpler [Tissue] factory is sufficient.
  ///
  /// ### How it works
  /// - You provide the [container] (storage strategy) and optional governance
  ///   parameters.
  /// - The framework creates a nucleus record that stores only non‑default
  ///   properties (memory optimisation).
  /// - The resulting nucleus can be used to instantiate multiple tissues that
  ///   share the same logic but hold separate data.
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream [Cell] to observe.
  /// - [context]: Operational environment (default: [Context.system]).
  /// - [receptor]: Mutation command processor (default: pass‑through).
  /// - [testRule]: Validation gatekeeper (default: allow all).
  /// - [synapses]: Propagation configuration (default: enabled).
  /// - [container]: **Required**. Physical storage strategy.
  /// - [user]: Optional metadata for custom logic.
  ///
  /// ### Returns:
  /// A concrete [TissueNucleus<E>] instance strictly configured
  /// according to the provided reactive blueprint.
  factory TissueNucleus(
      {Cell? bind,
      Context context,
      TissueReceptor<E, Tissue<E>> receptor,
      Container container,
      TestTissue<E, Tissue<E>> testRule,
      Synapses synapses,
      EphemeralPolicy? ephemeralPolicy,
      Record? user}) = _TissueNucleus<E, Iterable<E>, Tissue<E>>;

  /// Creates a specialized **Architectural Extension** of an existing [TissueNucleus]
  /// to support hierarchical property inheritance and contextual overrides for collections.
  ///
  /// This factory is the primary architectural implementation of **Prototypal
  /// Inheritance** and **Behavioural Shadowing** within the collection ecosystem.
  /// In the framework's biological meta-language, it creates a **Deputy**
  /// configuration that inherits the structural "DNA" and baseline rules of a
  /// [principal] while selectively applying directed **Genetic Mutations**.
  ///
  /// ### When to use
  /// - **Access Control**: Creating a restricted "Read-Only" view of a shared
  ///   storage pool by overriding the [testRule].
  /// - **Contextual Isolation**: Moving a collection into a different [Context]
  ///   (e.g., from `background` to `ui`) to change its processing priority.
  /// - **Transformation Overrides**: Swapping a [receptor] to apply different
  ///   mutation logic to the same underlying data.
  ///
  /// ### How it works
  /// The constructor utilizes a **Tiered Resolution Hierarchy** to determine the
  /// final state of any collection property:
  /// 1. **Local Override**: Values explicitly passed to this factory.
  /// 2. **Prototype Inheritance**: Values inherited from the [principal].
  /// 3. **Causal Binding**: Values derived from the upstream [bind] dependency.
  /// 4. **Global Default**: Framework-level constants (e.g., [Context.system]).
  ///
  /// ### Parameters:
  /// - [principal]: **Required**. The source nucleus from which this instance
  ///   derives its structural DNA and inheritance chain.
  /// - [ephemeralPolicy]: **Lifecycle Governance.** Defines the TTL for the
  ///   collection state.
  /// - [bind]: **Ingress Link.** An optional upstream [Cell] to observe.
  /// - [context]: **Operational Authority.** Defines the execution tier
  ///   (default: inherits from [principal]).
  /// - [receptor]: **Command Engine.** The logic used to process mutations
  ///   (default: inherits from [principal]).
  /// - [testRule]: **Integrity Gate.** Validation rules that guard the
  ///   collection (default: inherits from [principal]).
  /// - [synapses]: **Signal Distribution.** Manages egress connectivity
  ///   (default: inherits from [principal]).
  /// - [override]: **Composite Shadowing.** An optional, complete nucleus
  ///   whose internal record is adopted directly as the `local` tier.
  ///
  /// ### Returns:
  /// A new [TissueNucleus<E>] instance acting as a specialized behavioral
  /// layer over the [principal].
  factory TissueNucleus.evolve(TissueNucleus<E> principal, {
    EphemeralPolicy? ephemeralPolicy,
    Cell? bind,
    Context? context,
    TissueReceptor<E, Tissue<E>>? receptor,
    TestTissue<E, Tissue<E>>? testRule,
    Synapses? synapses,
    TissueNucleus<E>? override
  }) {
    return _TissueNucleus.fromRecord((
      local: override != null
          ? (override as NucleusBase).record.local
          : TissueNucleusBase.mask<E, Iterable<E>, Tissue<E>>(
              bind: bind,
              context: context,
              receptor: receptor,
              testRule: testRule,
              synapses: synapses,
              forceLock: true,
              ephemeralPolicy: ephemeralPolicy,
            ),
      principal: principal,
    ));
  }



  /// A specialised, terminal factory for creating a **Null Nucleus**—a stateless,
  /// immutable configuration representing a collection that can never contain
  /// data and rejects all mutations.
  ///
  /// The [TissueEvent.none] factory is a primary architectural implementation of the
  /// **Null Object Pattern** within the `cell_tissue` ecosystem. It is
  /// designed for scenarios where a [Tissue] identity is required by an
  /// interface or API, but the underlying state is conceptually "Never" or
  /// "Permanently Depleted."
  ///
  /// ### When to use
  /// Use this when you need a tissue placeholder that is guaranteed to be
  /// empty and immutable – e.g., as a fallback for a collection that is
  /// not yet initialised or for a terminal node in a graph.
  ///
  /// ### How it works
  /// - The factory returns a singleton [TissueNucleusNever] instance.
  /// - This nucleus has no storage, no synapses, and a testRule that rejects
  ///   all mutations.
  /// - It is the most memory‑efficient nucleus possible.
  ///
  /// ### Example
  /// ```dart
  /// final emptyNucleus = TissueNucleus.empty<int>();
  /// final emptyList = Tissue.fromNucleus(emptyNucleus);
  /// print(emptyList.length); // 0
  /// // emptyList.add(1); // throws or silently fails
  /// ```
  ///
  /// ### Returns:
  /// A `const` [TissueNucleus<E>] that represents a permanently empty,
  /// read‑only, and non‑allocating reactive blueprint.
  const factory TissueNucleus.empty() = TissueNucleusNever;

  /// A high‑fidelity, strategy‑based factory for creating specialised, type‑safe
  /// [TissueNucleus] blueprints for custom [Tissue] architectures.
  ///
  /// This method serves as the primary **Architectural Entry Point** for defining the
  /// behavioural and structural DNA of advanced collections. It facilitates
  /// the configuration of the element type [E], the internal physical storage
  /// implementation [I], and the public reactive interface [C].
  ///
  /// ### When to use
  /// Use this when the simple [TissueNucleus] factory is insufficient, and you
  /// need to:
  /// - Specify a custom storage strategy ([container]) with full type safety.
  /// - Provide a custom [receptor] or [testRule] typed to a specific
  ///   collection interface [C].
  /// - Extend an existing nucleus via [principal].
  ///
  /// ### How it works
  /// - It creates a nucleus with the provided parameters, inferring defaults
  ///   where omitted.
  /// - If a [principal] is provided, it creates an evolved nucleus that
  ///   inherits from that principal.
  /// - The [container] parameter determines the storage strategy.
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream cell.
  /// - [context]: Optional execution context.
  /// - [receptor]: Optional mutation processor.
  /// - [testRule]: Optional validation rule.
  /// - [synapses]: Optional propagation configuration.
  /// - [container]: Optional storage strategy.
  /// - [forceLock]: If `true`, shares the principal's lock.
  /// - [user]: Optional metadata.
  /// - [principal]: Optional ancestor nucleus to evolve.
  ///
  /// ### Returns:
  /// A [TissueNucleusBase<E, I, C>] instance configured as a
  /// stateless template for the specified collection architecture.
  static TissueNucleusBase<E, I, C>
      create<E, I extends Iterable<E>, C extends Tissue<E>>(
          {Cell? bind,
          Context? context,
          TissueReceptor<E, C>? receptor,
          TestTissue<E, C>? testRule,
          Synapses? synapses,
          Container? container,
          bool forceLock = false,
          Record? user,
          EphemeralPolicy? ephemeralPolicy,
          TissueNucleusBase<E, I, C>? principal}) {
    final local = TissueNucleusBase.mask<E, I, C>(
      bind: bind,
      context: context,
      receptor: receptor,
      testRule: testRule,
      synapses: synapses,
      container: container,
      forceLock: forceLock,
      user: user,
      ephemeralPolicy: ephemeralPolicy,
    );
    return _TissueNucleus<E, I, C>.fromRecord(principal != null
        ? (local: local, principal: principal)
        : (local: local));
  }

  /// The specialised [TissueReceptor] responsible for processing and
  /// applying mutation signals to the tissue state.
  ///
  /// In the framework's reactive architecture, the receptor acts as the
  /// primary **Command Engine** and input interceptor. When a mutation is
  /// requested (e.g., adding an element to a list or clearing a set), a
  /// [TissuePulse] pulse is dispatched to this receptor.
  ///
  /// ### When to use
  /// Read this to understand how the tissue processes mutations. This is
  /// useful for debugging or for custom receptors.
  ///
  /// ### How it works
  /// - The receptor is resolved by walking up the principal chain if not
  ///   defined locally.
  /// - It defaults to [TissueReceptor.passThrough] if no receptor is set.
  /// - The receptor is activated when the nucleus is bound to a tissue.
  ///
  /// ### Returns:
  /// The [TissueReceptor] instance governing the mutation logic
  /// for the associated collection.
  @override
  TissueReceptor get receptor;

  /// The [TissueContainer] responsible for managing the physical storage
  /// and low‑level data access for the associated tissue.
  ///
  /// The container acts as the **Physical Strategy** object in the reactive
  /// framework. It provides a standardised interface for index‑based access,
  /// iteration, and mutation while ensuring that the reactive system
  /// can observe and respond to changes.
  ///
  /// ### When to use
  /// You rarely need this directly – it is used internally by the tissue to
  /// access the underlying storage. However, you might read this for debugging
  /// or for advanced customisation.
  ///
  /// ### How it works
  /// - The container is resolved by walking up the principal chain if not
  ///   defined locally.
  /// - It is created when the nucleus is initialised with a [container]
  ///   strategy.
  /// - The container holds the actual Dart collection (List, Set, Map, etc.).
  ///
  /// ### Returns:
  /// An instance of [TissueContainer] that mediates between the reactive
  /// tissue and its physical memory storage.
  TissueContainer<E, Iterable<E>> get container;

  /// The [Container] template representing the physical storage strategy and
  /// structural blueprint for this collection's underlying data.
  ///
  /// While the [container] getter returns the live, active storage instance,
  /// [containerType] describes the *specification* or *type* of that storage.
  /// It defines whether the collection behaves as a `List`, `Set`, `Map`,
  /// or a custom structure, and dictates the default allocation behaviour
  /// when the collection is initialised.
  ///
  /// ### When to use
  /// Read this to understand what kind of storage the tissue uses (e.g., List,
  /// Set, Map). This is useful for conditional logic or debugging.
  ///
  /// ### How it works
  /// - The container type is resolved by walking up the principal chain if not
  ///   defined locally.
  /// - It is a structural property and cannot be changed through a deputy.
  /// - It defaults to [Container.create<E,I>()] if no container is set.
  ///
  /// ### Returns:
  /// A [Container] instance representing the structural template of
  /// the collection.
  Container get containerType;

  /// The [TestTissue] validation rules associated with this configuration.
  ///
  /// This getter provides the primary logic used to determine whether a
  /// proposed state change is valid before it is applied to the underlying
  /// collection. In the reactive `apply` cycle, the `testRule` acts as a
  /// guard or "middleware" that can intercept and reject operations.
  ///
  /// ### When to use
  /// Read this to understand the validation rules applied to the collection.
  /// This is useful for conditional UI logic (e.g., disabling an "Add" button)
  /// or for debugging.
  ///
  /// ### How it works
  /// - The testRule is resolved by walking up the principal chain if not
  ///   defined locally.
  /// - It defaults to [TestTissue.allowAll] if no rule is set.
  /// - For deputies, the rule is the composition of the principal's rule and
  ///   the deputy's additional rule.
  ///
  /// ### Returns:
  /// The [TestTissue] rule that governs the integrity and validity
  /// of this tissue's state transitions.
  @override
  TestTissue get testRule;

  /// Creates an independent, decoupled clone of the current [TissueNucleus]
  /// template.
  ///
  /// This getter implements the **Prototype Pattern** for reactive collection
  /// configurations. It generates a peer instance that replicates the behavioural
  /// logic and structural blueprint of the original without sharing its
  /// internal lifecycle state, observer registry, or synchronisation primitives.
  ///
  /// ### When to use
  /// You rarely need to call this directly. It is used internally when a nucleus
  /// needs to be cloned to avoid sharing locks between independent tissues.
  ///
  /// ### How it works
  /// - The clone retains the same [context], [receptor], [testRule], and
  ///   [containerType].
  /// - It allocates a brand‑new [Lock] and [Synapses] registry.
  /// - The clone is initially **inactive** – it must be activated by being
  ///   bound to a tissue instance.
  ///
  /// ### Returns:
  /// A new [TissueNucleus<E>] instance with identical behavioural
  /// logic and storage strategy, but an isolated lifecycle and an
  /// independent synchronisation lock.
  @override
  TissueNucleus<E> get clone;
}
