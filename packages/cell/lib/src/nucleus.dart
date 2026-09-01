// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell.dart';

/// The immutable blueprint underlying every [Cell] — its [receptor],
/// [testRule], [context], [synapses], and lifecycle policy, stored
/// separately from the live cell instance.
///
/// **You will almost never construct or reference this directly.** Every
/// `Cell.*` factory builds one internally from the parameters you already
/// pass it. This class exists so that behavior (the nucleus) can be
/// shared, cloned, and specialized independently of state — which is what
/// makes [Cell.deputy] cheap: a deputy is a new nucleus pointing back at
/// its principal, not a duplicated cell.
///
/// ### The one thing worth knowing
/// A nucleus can have a [principal] — an ancestor it falls back to for any
/// property it doesn't define locally. This is why a deputy created with
/// only a narrower [TestCell] still has the same [receptor] and [context]
/// as the cell it was made from: it didn't copy them, it inherits them by
/// walking up to [principal] on each lookup.
///
/// ### If you do need this directly
/// [Nucleus.create] and [Nucleus.evolve] are the entry points for
/// building custom cell types or framework-level tooling — not for
/// typical application code. If you find yourself reaching for these,
/// double-check whether [Cell.governed] or [Cell.deputy] already covers
/// what you need.
///
/// See also: [Cell.fromNucleus] (how a nucleus becomes a live cell),
/// [Cell.deputy] (the common, higher-level way this class gets used).
/// {@category Advanced}
/// {@category Nucleus}
abstract interface class Nucleus {

  /// The primary factory constructor for [Nucleus], which initializes a
  /// memory-optimized, tiered configuration for a reactive [Cell].
  ///
  /// ### When to use
  /// Only if you are building custom infrastructure that needs to define
  /// a cell's behavior from scratch. For most cases, use the higher‑level
  /// `Cell` factories.
  ///
  /// ### How it works
  /// All parameters are optional and default to framework standards.
  /// The constructor uses bitmasking to store only non‑default values,
  /// making it memory‑efficient.
  ///
  /// ### Non‑obvious
  /// - The [forceLock] parameter controls whether a new synchronization
  ///   lock is created. If `true`, the nucleus gets its own lock; if `false`,
  ///   it inherits from its principal (if any) or uses a shared default.
  /// - The [synapses] default is [Synapses.enabled], but you can pass
  ///   [Synapses.disabled] to make the cell a terminal node.
  ///
  /// ### Parameters:
  /// - [ephemeralPolicy]: **Lifecycle Governance.** Defines when the node
  ///   should be automatically neutralized and purged.
  /// - [bind]: **Ingress Link.** Establishes a dependency on an upstream [Cell].
  /// - [context]: **Operational Authority.** Defines the priority and semantic
  ///   domain of the node. Defaults to [Context.system].
  /// - [receptor]: **Transformation Pipeline.** The logic used to process
  ///   incoming [Pulse] signals.
  /// - [testRule]: **Integrity Gate.** Validation rules that act as a gate
  ///   for all state modifications. Defaults to [TestCell.allowAll].
  /// - [synapses]: **Egress Network.** Manages the connectivity and
  ///   distribution of signals to downstream observers.
  /// - [forceLock]: **Atomic Isolation.** If true, forces the allocation of
  ///   a unique [Lock], establishing a sovereign **Atomic Domain** isolated
  ///   from principal inheritance.
  /// - [user]: **Extension Metadata.** An optional record for domain-specific
  ///   properties kept separate from framework logic.
  factory Nucleus({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context context,
    Receptor receptor,
    TestCell testRule,
    Synapses synapses,

    bool forceLock,

    Record? user,
  }) = _Nucleus;

  /// Creates a specialized **Architectural Extension** of an existing [Nucleus] to
  /// support hierarchical property inheritance and contextual overrides.
  ///
  /// This factory constructor is the primary implementation of the **Prototype-based
  /// Inheritance** pattern (specifically the **Proxy/Deputy Pattern**) within the
  /// framework. It allows a derived **Blueprint** to inherit its core configuration
  /// and behavioral logic from a [principal] while layering on its own specific
  /// overrides, execution contexts, or ad-hoc metadata.
  ///
  /// ### When to use
  /// Only if you are building framework extensions. For deputies, use
  /// [Cell.deputy] instead.
  ///
  /// ### How it works
  /// You provide a [principal] (the parent nucleus) and override specific
  /// properties (e.g., [context], [testRule]). Missing properties are
  /// resolved by walking up the principal chain.
  ///
  /// ### Non‑obvious
  /// - The [override] parameter, if provided, replaces all local overrides.
  /// - Bindings ([bind]) are not inherited – they are instance‑specific.
  /// - The lock is inherited from the principal unless [override] provides
  ///   its own lock.
  ///
  /// ### Parameters:
  /// - [ephemeralPolicy]: **Lifecycle Governance.** Defines when the node
  ///   should be automatically neutralized and purged. If null, resolves
  ///   from the [principal]. *(Ignored if [override] is set)*.
  /// - [bind]: Optional. A [Cell] dependency. Note: bindings are
  ///   instance-specific and are **not** inherited from the [principal].
  ///   *(Ignored if [override] is set)*.
  /// - [context]: **Execution Environment.** Defines the security tier and
  ///   priority of the node. If null, resolves from the [principal].
  ///   *(Ignored if [override] is set)*.
  /// - [receptor]: **Transformation Pipeline.** The logic used to process
  ///   incoming signals. If null, resolves from the [principal].
  ///   *(Ignored if [override] is set)*.
  /// - [testRule]: **Integrity Gate.** Validation rules that act as a guard
  ///   for all state modifications. If null, resolves from the [principal].
  ///   *(Ignored if [override] is set)*.
  /// - [synapses]: **Signal Manifest.** Manages connectivity and distribution
  ///   via the `SignalDistributionHub`. If null, resolves from the [principal].
  ///   *(Ignored if [override] is set)*.
  /// - [user]: **Extension Metadata.** An optional record for domain-specific
  ///   properties kept separate from framework logic.
  /// - [override]: Optional. A pre-compiled [Nucleus] whose record will be
  ///   directly adopted as the property base.
  /// - [principal]: **Required**. The source [Nucleus] from which this instance
  ///   derives its structural and logic inheritance.
  factory Nucleus.evolve({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context? context,
    Receptor? receptor,
    TestCell? testRule,
    Synapses? synapses,
    Record? user,

    Nucleus? override,
    required Nucleus principal
  }) = _Nucleus.evolve;

  /// Creates a primary, immutable, and completely empty [Nucleus] instance.
  ///
  /// This `const` factory constructor represents the "Zero State" of the
  /// framework's property system. It returns a specialized, lightweight
  /// implementation that contains no local overrides, metadata, or principal links.
  ///
  /// ### When to use
  /// You never call this directly – the framework uses it internally as the
  /// root of the inheritance chain.
  ///
  /// ### Returns:
  /// A `const` [Nucleus] instance configured with global framework defaults.
  factory Nucleus.empty() => Nucleolus._singleton;

  /// A versatile static factory for creating a [Nucleus] configuration, serving
  /// as the architectural **Blueprint** for a [Cell] of type [C].
  ///
  /// This method is the primary entry point for defining the behavioral,
  /// security, and operational constraints of a reactive node. It supports
  /// the creation of both standalone "Root" property sets and specialized
  /// "Extended" sets that inherit from an existing [principal].
  ///
  /// ### When to use
  /// This is an advanced entry point for custom cell types. Most developers
  /// should use [Cell] or [ValueCell] factories.
  ///
  /// ### How it works
  /// You provide a set of parameters; the method creates a nucleus record.
  /// If [principal] is provided, the new nucleus inherits from it.
  ///
  /// ### Non‑obvious
  /// - The [forceLock] semantics differ from the primary constructor:
  ///   if `true`, the nucleus shares the principal's lock (i.e., does not
  ///   create a new one). This is the opposite of the primary constructor
  ///   where `true` means *create* a lock.
  /// - The [receptor] and [testRule] are type‑bound to [C], ensuring
  ///   compile‑time safety.
  ///
  /// ### Parameters:
  /// * [ephemeralPolicy]: Optional. The **Lifecycle Governance Policy** (TTL/Hops).
  ///   If null and a [principal] is provided, it is inherited from the principal.
  /// * [bind]: Optional. An upstream [Cell] to which the governed cell's
  ///   lifecycle or state is reactively bound.
  /// * [context]: Optional. The **Operational Environment**. Determines
  ///   execution priority, security tier, and authority context.
  /// * [receptor]: Optional. The **Transformation Pipeline** specialized for
  ///   type [C] that orchestrates how incoming signals are applied to the state.
  /// * [testRule]: Optional. The **Policy Guard** validator used to authorize
  ///   and validate state changes.
  /// * [synapses]: Optional. Configuration for the **Signal Distribution Network**.
  /// * [forceLock]: Optimization flag. If `true`, the nucleus will share the
  ///   synchronization domain of its [principal].
  /// * [user]: Optional [Record] for developer-defined ad-hoc metadata
  ///   kept separate from core framework logic.
  /// * [principal]: Optional. An ancestor [Nucleus] to extend via the
  ///   [evolve] pattern, establishing a prototype-based inheritance link.
  ///
  /// ### Returns:
  /// A [Nucleus] instance configured as a stateless blueprint for the
  /// specified reactive node.
  static Nucleus create<C extends Cell>({
    EphemeralPolicy<C>? ephemeralPolicy,

    Cell? bind,
    Context? context,
    Receptor<C>? receptor,
    TestCell<C>? testRule,
    Synapses? synapses,

    bool forceLock = false,
    Record? user,
    Nucleus? principal
  }) {
    if (principal != null) {
      final local = NucleusBase.mask(bind: bind, context: context, receptor: receptor,
        testRule: testRule, synapses: synapses, forceLock: forceLock, user: user);
      return _Nucleus.fromRecord((mask: local, principal: principal));
    }
    return _Nucleus(
      bind: bind,
      context: context ?? Context.system,
      receptor: receptor ?? Receptor.passThrough,
      testRule: testRule ?? TestCell.allowAll,
      synapses: synapses ?? Synapses.enabled,
      user: user,
      forceLock: forceLock
    );
  }

  /// Activates this nucleus by binding it to a live [Cell] instance.
  ///
  /// ### When to use
  /// You never call this – the framework does it automatically when you
  /// create a cell from a nucleus via [Cell.fromNucleus].
  ///
  /// ### How it works
  /// It establishes the bidirectional link between the nucleus and the cell.
  /// After activation, [isActivated] returns `true` and [cell] becomes
  /// accessible.
  ///
  /// ### Returns:
  /// - `true`: If the nucleus was successfully bound to the cell.
  /// - `false`: If the nucleus is already activated, the cell is invalid,
  ///   or an internal error occurred.
  bool activate(covariant Cell cell);

  /// Returns the live [Cell] instance that this nucleus is bound to.
  ///
  /// ### When to use
  /// Mostly for internal framework code. You rarely need this directly.
  ///
  /// ### Non‑obvious
  /// This getter is only valid when [isActivated] is `true`. Accessing it
  /// on an unactivated nucleus throws a [StateError].
  Cell get cell;

  /// Indicates whether this nucleus has been bound to a live [Cell].
  ///
  /// ### When to use
  /// Debugging or diagnostic tools. You rarely need this in application code.
  ///
  /// ### How it works
  /// Returns `true` after [activate] has been called successfully.
  bool get isActivated;

  /// Indicates whether the associated [Cell] has been formally invalidated
  /// and neutralized by its **Lifecycle Governance Policy**.
  ///
  /// ### When to use
  /// Use this as a safety check before interacting with a cell, especially
  /// if it has an [EphemeralPolicy].
  ///
  /// ### How it works
  /// Delegates to the [EphemeralPolicy] associated with this nucleus.
  /// Returns `true` if the policy has triggered invalidation.
  bool get isInvalidated;

  /// Indicates whether this nucleus is subject to a **Governance Policy**.
  ///
  /// ### When to use
  /// This is mostly informational – you might use it to conditionally apply
  /// stricter checks in custom receptors.
  ///
  /// ### How it works
  /// Returns `true` if the nucleus's context contains governance metadata
  /// (e.g., it was created with a non‑default [Context]).
  bool get isGoverned;

  /// The synchronization primitive used to ensure thread-safe and atomic
  /// operations across the reactive [Cell] associated with this [Nucleus].
  ///
  /// ### When to use
  /// You typically don't need this – the framework handles locking
  /// automatically. Use it only for advanced manual synchronization.
  ///
  /// ### How it works
  /// Returns the [Lock] instance that protects this cell's state. May be
  /// `null` if the nucleus is not yet activated or if it uses a shared lock.
  Lock? get lock;

  /// The connectivity manager responsible for tracking and notifying downstream
  /// observers of this [Cell].
  ///
  /// ### When to use
  /// You can inspect this to see what observers are linked, but you normally
  /// use [Synapses.link]/[Synapses.unlink] to modify it.
  ///
  /// ### How it works
  /// Returns the [Synapses] instance that manages the observer registry.
  /// If synapses are disabled, returns [Synapses.disabled].
  Synapses get synapses;

  /// The upstream [Cell] dependency that serves as the primary **Ingress Source**
  /// for this node's reactive logic.
  ///
  /// ### When to use
  /// You rarely read this – it's set when you create a cell with `bind:`.
  ///
  /// ### How it works
  /// Returns the cell this nucleus is bound to, or `null` if none.
  /// This is not inherited from the principal.
  Cell? get bind;

  /// Retrieves the optional [Record] containing developer-defined metadata or
  /// custom property extensions for the associated [Cell].
  ///
  /// ### When to use
  /// Use this to attach custom data to a cell's blueprint – e.g.,
  /// configuration flags, UI hints, etc.
  ///
  /// ### How it works
  /// The `user` record is stored in the nucleus. It is resolved by walking
  /// up the principal chain if not defined locally.
  Record? get user;

  /// Retrieves the optimized **Logic Inheritance Handle** containing the
  /// shared behavioral configuration for this [Nucleus].
  ///
  /// ### When to use
  /// This is an internal handle used by the framework for efficient
  /// property resolution. You don't need to use it directly.
  ///
  /// ### How it works
  /// It aggregates [context], [receptor], and [testRule] into a single
  /// record that can be shared across multiple nuclei.
  InheritableHandle get inheritable;

  /// The **Transformation Pipeline** and pulse processing engine for the
  /// associated [Cell].
  ///
  /// ### When to use
  /// You typically define this when creating a custom cell; you rarely
  /// read it directly.
  ///
  /// ### How it works
  /// Returns the [Receptor] that processes incoming pulses. It is resolved
  /// by walking up the principal chain if not defined locally.
  Receptor get receptor;

  /// The **Policy Guard** and integrity engine responsible for governing state
  /// mutations and operational permissions for the associated [Cell].
  ///
  /// ### When to use
  /// Use this to inspect or compose validation rules. You rarely modify it
  /// directly; instead, use `Cell.deputy` with a new [TestCell].
  ///
  /// ### How it works
  /// Returns the [TestCell] that validates all state changes. It is resolved
  /// by walking up the principal chain.
  TestCell get testRule;

  /// The operational tier and execution environment assigned to the [Cell]
  /// associated with this [Nucleus].
  ///
  /// ### When to use
  /// You can read this to get the cell's security tier or domain. You rarely
  /// set it directly – use `Cell.governed` with a [Context] instead.
  ///
  /// ### How it works
  /// Returns the [Context] instance. It is resolved by walking up the
  /// principal chain; defaults to [Context.system].
  Context get context;

  /// The optional reference to a precursor [Nucleus] in the inheritance
  /// hierarchy.
  ///
  /// ### When to use
  /// Rarely – this is mostly used internally to resolve inherited properties.
  ///
  /// ### How it works
  /// Returns the parent nucleus, or `null` if this is the root.
  Nucleus? get principal;

  /// The **Temporal Origin** and synthesis record of this [Nucleus] instance.
  ///
  /// ### When to use
  /// Debugging – to know when a cell's blueprint was created.
  ///
  /// ### How it works
  /// Returns the [DateTime] when this nucleus was constructed.
  DateTime get timestamp;

  /// Generates a decoupled, peer-level replica of the current [Nucleus] blueprint
  /// with an independent synchronization domain.
  ///
  /// ### When to use
  /// Almost never – the framework uses it internally when you create a
  /// cell from an already‑activated nucleus.
  ///
  /// ### How it works
  /// Creates a new nucleus with the same logic but a fresh lock and
  /// synapse registry, so it can be used to create an independent cell.
  Nucleus get clone;

}