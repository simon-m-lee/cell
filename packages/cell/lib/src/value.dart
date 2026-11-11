// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell.dart';

/// A management record that bundles a [ValueCell] with its imperative update
/// functions — the standard way to create and interact with a state atom.
///
/// ### When to use
/// You get this from [Cell.state]. It gives you:
/// - `cell`: the reactive state container (read‑only observation).
/// - `update`: a synchronous function to update the state.
/// - `updateAsync`: an asynchronous, lock‑protected version of `update`.
/// - `ingest`: a low‑level entry point for full [Pulse] injection.
///
/// ### How it works
/// The handle separates the observable cell (safe to share) from the
/// mutation functions (keep them private to the owner). This enforces a
/// strict write‑privilege model – observers can only read, the owner can
/// write.
///
/// ### Type Parameters:
/// * [V]: The type of the value managed by this state handle.
typedef StateHandle<V> = ({
  /// The persistent, observable reactive node.
  ValueCell<V> cell,

  /// Synchronously emits a state transition.
  ///
  /// Returns `true` if the value was successfully committed. A no-op
  /// update (a value `identical` to or `==` the current state) is
  /// deduplicated: nothing is emitted and `false` is returned — a skipped
  /// update is deliberately not a commit.
  bool Function(V? value) update,

  /// Asynchronously emits a state transition, ensuring atomic
  /// serialization through the cell's synchronization lock.
  Future<bool> Function(V? value) updateAsync,

  /// The primary ingress handle for direct signal orchestration.
  ///
  /// Set `serializedCompletion` to `true` to wait for the entire reactive
  /// graph to reach a stable state before the future completes.
  Future<void> Function(Pulse<V> pulse, {bool serializedCompletion}) ingest
});

/// A specialized [Nucleus] blueprint designed to manage and propagate a
/// discrete, persistent state value of type [V].
///
/// This is the internal blueprint that powers [ValueCell]. You almost never
/// construct it directly – [Cell.state] does it for you.
///
/// ### When to use
/// Only if you're building custom cell types or advanced tooling. For
/// application code, use [Cell.state].
///
/// ### How it works
/// It holds a [Box<V>] (the physical storage) and integrates the
/// transformation logic ([transform]) with the commitment pipeline
/// ([ValueCell.postProcessRule]). The [Box] is resolved by walking up the
/// principal chain, so deputies share the same storage.
///
class ValueNucleus<V> extends NucleusBase {
  ValueNucleus._(super.record) : super.fromRecord();

  /// Default-enabled records store the [Synapses.enabled] flyweight; the
  /// real set is materialized once on first access.
  @override
  late final Synapses synapses = _resolveSynapses();

  Synapses _resolveSynapses() {
    final stored =
        get<Synapses>(() => record.local.synapses, orElse: Synapses.disabled);
    if (stored != Synapses.enabled) return stored;
    return Synapses();
  }

  /// Initializes a new primary `ValueNucleus` – the blueprint for a stateful
  /// cell.
  ///
  /// ### When to use
  /// You almost never call this directly – [Cell.state] does it for you.
  ///
  /// ### How it works
  /// It allocates a `Box<V>` for storage, sets up a transformation
  /// pipeline from the `transform` function, and integrates the commitment
  /// rule. If you provide a custom `receptor`, you must manually include
  /// `ValueCell.postProcessRule` to persist state.
  ///
  /// ### Parameters:
  /// * [transform]: **Transformation Logic.** An optional function defining
  ///   how input signals are converted into state updates.
  /// * [bind]: **Upstream Dependency.** An optional [Cell] that this nucleus
  ///   subscribes to for automatic updates.
  /// * [context]: **Environmental Scope.** Defines the authority and
  ///   security tier (defaults to [Context.system]).
  /// * [receptor]: **Execution Interface.** Overridden if [transform] is
  ///   provided. If customized, it must handle state persistence manually.
  /// * [testRule]: **Security Gate.** A [TestCell] predicate used to
  ///   validate proposed state changes (defaults to [TestCell.allowAll]).
  /// * [synapses]: **Signal Distribution.** Controls how updates are
  ///   broadcast to the rest of the graph.
  /// * [user]: **Extended Metadata.** An optional [Record] of application-specific
  ///   traits carried by the nucleus blueprint.
  ValueNucleus(
      {Pulse<V>? Function(ValueCell<V> host, Pulse input, {dynamic user})?
          transform,
      Cell? bind,
      Context context = Context.system,
      Receptor receptor = Receptor.passThrough,
      TestCell testRule = TestCell.allowAll,
      Synapses synapses = Synapses.enabled,
      EphemeralPolicy? ephemeralPolicy,
      Record? user,
      bool forceLock = true})
      : this._((
          local: NucleusBase.mask(
              bind: bind,
              context: context,
              testRule: testRule,
              synapses: synapses,
              forceLock: forceLock,
              user: user,
              ephemeralPolicy: ephemeralPolicy,
              receptor: transform != null
                  ? Receptor.pipeline(
                      instruction: Instruction<ValueCell<V>, Pulse, Pulse<V>>(
                          (pulse, {cell, user, delayPropagation, token}) =>
                              transform(cell!, pulse, user: user)),
                      postProcess: ValueCell.postProcessRule)
                  : receptor == Receptor.passThrough
                      ? Receptor.pipeline(
                          postProcess: ValueCell.postProcessRule)
                      : receptor,
              others: (value: Box<V>()))
        ));

  /// Initializes a new primary `ValueNucleus` using a pre‑configured
  /// [Instruction] – the preferred way to reuse transformation logic.
  ///
  /// ### When to use
  /// When you have a reusable [Instruction] that you want to apply to
  /// multiple state cells.
  ///
  /// ### How it works
  /// It pairs the provided [instruction] with [ValueCell.postProcessRule] to form
  /// a complete commitment pipeline. The nucleus gets a fresh `Box` and
  /// lock.
  ///
  /// ### Parameters:
  /// * [instruction]: **The Transformation Blueprint.** A formal [Instruction] defining
  ///   how stimuli are converted into state. If provided, it overrides
  ///   the [receptor] parameter.
  /// * [bind]: **The Upstream Dependency.** An optional [Cell] that this nucleus
  ///   subscribes to for automatic updates.
  /// * [context]: **The Environmental Scope.** Defines the authority and
  ///   security tier (defaults to [Context.system]).
  /// * [receptor]: **The Processing Interface.** Overridden if [instruction] is
  ///   provided. If customized manually, it must handle [Box] commitment.
  /// * [testRule]: **The Security Gate.** A [TestCell] predicate used to
  ///   validate proposed state changes (defaults to [TestCell.allowAll]).
  /// * [synapses]: **The Distribution Controller.** Controls how updates are
  ///   broadcast to the rest of the reactive graph.
  /// * [user]: **Extended Metadata.** An optional [Record] of application-specific
  ///   traits carried by the nucleus blueprint.
  ValueNucleus.from(
      {Instruction<ValueCell<V>, Pulse, Pulse<V?>>? instruction,
      Cell? bind,
      Context context = Context.system,
      Receptor receptor = Receptor.passThrough,
      TestCell testRule = TestCell.allowAll,
      Synapses synapses = Synapses.enabled,
      EphemeralPolicy? ephemeralPolicy,
      Record? user})
      : this._(((
          local: NucleusBase.mask(
              bind: bind,
              context: context,
              testRule: testRule,
              synapses: synapses,
              forceLock: false,
              user: user,
              ephemeralPolicy: ephemeralPolicy,
              receptor: instruction != null
                  ? Receptor.pipeline(
                      instruction: instruction,
                      postProcess: ValueCell.postProcessRule)
                  : receptor == Receptor.passThrough
                      ? Receptor.pipeline(
                          postProcess: ValueCell.postProcessRule)
                      : receptor,
              others: (value: Box<V>()))
        )));

  /// Synthesizes a derivative `ValueNucleus` that shares the same physical
  /// state ([Box]) as its [principal] but may override behavior (rule,
  /// context, testRule, etc.).
  ///
  /// ### When to use
  /// This is used by [Cell.deputy] internally to create a proxy with a
  /// different transformation or validation logic, while sharing the same
  /// state.
  ///
  /// ### How it works
  /// The new nucleus does not allocate a new `Box`. Instead, it delegates
  /// storage resolution to the [principal]. Overrides are applied locally;
  /// missing properties are inherited from the principal.
  ///
  /// ### Parameters:
  /// * [instruction]: **The Specialization Logic.** An optional [Instruction]
  ///   defining a new transformation strategy for this deputy.
  /// * [principal]: **The Authoritative Source.** (Required) The parent
  ///   [ValueNucleus] providing the physical state [Box] and synchronization lock.
  /// * [bind]: **Dependency Re-anchoring.** Connects this nucleus to a
  ///   different upstream [Cell] if the specialization requires a different
  ///   emit source.
  /// * [context]: **Environmental Authority.** Overrides the execution
  ///   authority (e.g., shifting a system-level cell into a user-restricted context).
  /// * [testRule]: **Security Adaptation.** Overrides the validation logic,
  ///   commonly used to make a child node more restrictive than its parent.
  /// * [synapses]: **Distribution Regulation.** Overrides how this deputy
  ///   broadcasts updates (e.g., making a node terminal/private).
  /// * [override]: An optional nucleus that this instance should proxy its
  ///   behavior to, used for complex structural redirections.
  ///
  /// ### Returns:
  /// A derivative [ValueNucleus] sharing the same physical state as the [principal].
  ValueNucleus.evolve(
      {Instruction<ValueCell<V>, Pulse, Pulse<V?>>? instruction,
      EphemeralPolicy? ephemeralPolicy,
      Cell? bind,
      Context? context,
      Receptor? receptor,
      TestCell? testRule,
      Synapses? synapses,
      Record? user,
      ValueNucleus? override,
      required ValueNucleus principal})
      : this._((
          local: override?.record.local ??
              NucleusBase.mask(
                  bind: bind,
                  context: context,
                  receptor: instruction != null
                      ? Receptor.pipeline(
                          instruction: instruction,
                          postProcess: ValueCell.postProcessRule)
                      : receptor == Receptor.passThrough
                          ? Receptor.pipeline(
                              postProcess: ValueCell.postProcessRule)
                          : receptor,
                  testRule: testRule,
                  // A derivative needs a working egress registry. `null`
                  // would fall through the mask to `Synapses.disabled`
                  // (the orElse), silently orphaning every observer linked
                  // to the projection — the same trap the `clone` path
                  // documents and avoids by materializing `Synapses()`.
                  synapses: synapses ?? Synapses.enabled,
                  user: user,
                  ephemeralPolicy: ephemeralPolicy),
          principal: principal
        ));

  /// Resolves the physical [Box] storage container that holds the current
  /// state.
  ///
  /// ### When to use
  /// You usually don't need this – use [ValueCell.initial] instead.
  ///
  /// ### How it works
  /// The getter walks up the principal chain to find the root nucleus that
  /// originally allocated the `Box`. This ensures that all deputies share
  /// the same storage.
  Box<V> get state => get<Box<V>>(() => record.local.others.value,
      fallback: () => principal!.state, orElse: null);

  @override
  ValueNucleus<V>? get principal => super.principal as ValueNucleus<V>?;

  @override
  ValueNucleus<V> get clone {
    final handle = inheritable;
    return ValueNucleus<V>._((
      local: NucleusBase.mask(
        bind: handle.bind,
        context: handle.context,
        receptor: handle.receptor.clone,
        testRule: handle.testRule,
        ephemeralPolicy: handle.ephemeralPolicy,
        // Materialize a working egress registry: the `enabled` flyweight
        // rejects every `link`, which would silently orphan the clone's
        // observers.
        synapses:
            synapses != Synapses.disabled ? Synapses() : Synapses.disabled,
        user: user,
        forceLock: lock != null,
      ),
      principal: this
    ));
  }
}

/// A state‑bearing reactive node – the primary way to manage persistent
/// state in the Cell Framework.
///
/// ### When to use
/// You almost always create a [ValueCell] via [Cell.state]. That gives you
/// a [StateHandle] with a `cell` and update functions.
///
/// ### How it works
/// A `ValueCell` holds a state in a `Box` (physical storage). It uses a
/// [Receptor] to process incoming pulses through a `transform` function,
/// validates the result with a `testRule`, and commits the new state to
/// the `Box`. Changes are then broadcast to observers via [Synapses].
///
class ValueCell<V> extends CellBase {
  /// A static, reusable [Instruction] that commits a validated pulse to the
  /// cell's `Box`.
  ///
  /// This is the "commitment stage" of the pipeline. It's used internally
  /// by `ValueCell` and `ValueNucleus`. You don't need to call it directly.
  static Instruction postProcessRule =
      Instruction<ValueCell, Pulse, Pulse>((pulse, {cell, user}) {
    cell!._nucleus.state.value = pulse.payload;
    return pulse;
  });

  @override
  ValueNucleus<V> get _nucleus => super._nucleus as ValueNucleus<V>;

  /// Initializes a new primary `ValueCell` – the standard state atom.
  ///
  /// ### When to use
  /// You typically use [Cell.state] instead of this constructor directly.
  ///
  /// ### How it works
  /// It creates a `ValueNucleus` with the given parameters, then seeds the
  /// initial `state` directly into the `Box` (bypassing the transform).
  ///
  /// ### Parameters:
  /// *   `transform`: **The Reactive Brain.** An optional functional unit
  ///     that defines the cell's "metabolism."
  /// *   `initial`: **The Initial Seed.** An optional value of type [V?] that
  ///     establishes the cell's foundational state. This value is written
  ///     directly to the internal [Box] during the construction phase.
  /// *   `bind`: **The Upstream Anchor.** An optional principal [Cell] that this
  ///     instance "watches".
  /// *   `context`: **The Operational Scope.** Defaults to [Context.system].
  /// *   `receptor`: **The Low-Level Gateway.** The underlying [Receptor] logic.
  /// *   `testRule`: **The Immune System.** A compositional [TestCell]
  ///     (defaulting to [TestCell.allowAll]).
  /// *   `synapses`: **The Propagation Engine.** Controls how this cell
  ///     communicates with downstream dependents ([Synapses.enabled] by default).
  ValueCell({
    Pulse<V>? Function(ValueCell<V> host, Pulse input,
            {dynamic user, Cell? bind})?
        transform,
    V? initial,
    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : this.fromNucleus(
            ValueNucleus<V>(
                transform: transform,
                bind: bind,
                context: context,
                receptor: receptor,
                testRule: testRule,
                synapses: synapses),
            initial: initial);

  /// Creates a terminal `ValueCell` that never broadcasts its state changes.
  ///
  /// ### When to use
  /// Use this for cells that should be pure sinks – they hold state but
  /// don't notify observers. Good for private data or when you want to
  /// avoid unnecessary propagation.
  ///
  /// ### How it works
  /// It's just like a normal `ValueCell` but with `Synapses.disabled`.
  ///
  /// ### Example
  /// ```dart
  /// final counter = ValueCell.terminal<int>(
  ///   state: 0,
  ///   transform: (host, input, {user}) => Pulse(host.state + 1),
  /// );
  /// // No observers will be notified of changes
  /// ```
  ValueCell.terminal({
    Pulse<V>? Function(ValueCell<V> host, Pulse input,
            {dynamic user, Cell? bind})?
        transform,
    V? initial,
    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
  }) : this(
            synapses: Synapses.disabled,
            transform: transform,
            bind: bind,
            context: context,
            receptor: receptor,
            testRule: testRule,
            initial: initial);

  /// Initializes a [ValueCell] from an existing [ValueNucleus] – used
  /// internally for blueprint hydration.
  ///
  /// ### When to use
  /// This is used by the framework when you create a cell from a nucleus
  /// (e.g., when restoring from a saved state). You rarely call it yourself.
  ///
  /// ### How it works
  /// It binds the nucleus to the cell and optionally seeds an initial state
  /// directly (bypassing the transform).
  ///
  /// ### Parameters:
  /// * [nucleus]: **Required.** The [ValueNucleus] that defines the behavior,
  ///   storage schema, and environmental [Context] for this cell.
  /// * [initial]: An optional initial state of type [V?]. If provided, it
  ///   populates the cell's storage immediately, overwriting any
  ///   previous data in the nucleus's associated [Box].
  ///
  /// ### Returns:
  /// A fully hydrated [ValueCell] instance ready for reactive interaction.
  ValueCell.fromNucleus(ValueNucleus<V> super.nucleus, {V? initial})
      : super.fromNucleus() {
    if (initial != null) {
      _nucleus.state.value = initial;
    }
  }

  /// A high-level static factory that synthesizes a [ValueCell] and its
  /// operational [StateHandle] in a single atomic operation.
  ///
  /// ### When to use
  /// - **Internal Engine**: The primary factory behind [Cell.state]. You rarely
  ///   need to call this directly.
  /// - **Custom Abstractions**: Use this when building specialized [Cell]
  ///   types that require manual [ValueNucleus] hydration.
  ///
  /// ### How it works
  /// 1. **Hydration**: Instantiates a [ValueCell] from the [nucleus] blueprint.
  /// 2. **Seeding**: Writes the [initial] value directly to storage, bypassing
  ///    the transformation pipeline.
  /// 3. **Handle Synthesis**: Creates a suite of closures (`update`,
  ///    `updateAsync`, `ingest`) that bridge imperative calls to the cell's
  ///    internal [Receptor].
  ///
  /// ### Parameters:
  /// * [nucleus]: The blueprint defining the cell's identity and logic.
  /// * [initial]: An optional initial state to seed the cell's storage. This
  ///   bypasses the transformation pipeline and is applied immediately.
  ///
  /// ### Returns:
  /// A [StateHandle] containing the `cell` and its associated mutation
  /// primitives (`update`, `updateAsync`, and `ingest`).
  ///
  /// ### See Also:
  /// - [Cell.state]: The standard application-level API for state creation.
  /// - [ValueNucleus]: The underlying blueprint used to configure this factory.
  /// - **How-To**: See `guide/HowTo-Start.md` for a guide on state management.
  static StateHandle<V> create<V>(ValueNucleus<V> nucleus, {V? initial}) {
    final cell = ValueCell<V>.fromNucleus(nucleus, initial: initial);
    final valueCellAsync = ValueCellAsync<V>(cell);
    final receptor = nucleus.receptor;

    Future<void> ingest(Pulse<V> pulse, {bool serializedCompletion = true}) {
      return receptor.async
          .call(pulse as PulseBase, serializedCompletion: serializedCompletion);
    }

    return (
      cell: cell,
      update: cell._emit,
      updateAsync: valueCellAsync._emit,
      ingest: ingest
    );
  }

  /// A factory for creating a custom [Receptor] that is pre‑integrated with
  /// the state commitment pipeline.
  ///
  /// ### When to use
  /// Use this when you need a custom transformation logic for a `ValueCell`
  /// – it's safer than manually constructing a `Receptor` because it
  /// automatically includes the commitment rule.
  ///
  /// ### How it works
  /// The provided `transform` function is wrapped in a `Instruction`, and the
  /// result is paired with [ValueCell.postProcessRule] as the post‑process
  /// stage. This guarantees that every valid pulse is persisted to the Box.
  ///
  /// ### Example
  /// ```dart
  /// final receptor = ValueCell.receptor<int>((host, input, {user}) {
  ///   final v = input.payload as int;
  ///   return Pulse(v * 2);
  /// });
  /// final cell = ValueCell<int>(state: 0, receptor: receptor);
  /// ```
  ///
  /// ### Parameters:
  /// * [transform]: **The Transformation Logic.** A callback that defines how
  ///   an incoming `Pulse` is interpreted by the `host` cell.
  ///   - `host`: The specific `ValueCell` instance receiving the stimulus.
  ///   - `input`: The raw `Pulse` arriving from the environment or an
  ///     upstream synapse.
  ///   - `user`: Optional contextual metadata passed along with the pulse.
  ///
  /// ### Returns:
  /// A [Receptor] configured to govern the ingress processing path for a
  /// [ValueCell].
  static Receptor receptor<V>(
      Pulse<V?>? Function(ValueCell<V> host, Pulse input, {dynamic user})
          transform) {
    return Receptor.pipeline(
        instruction: Instruction<ValueCell<V>, Pulse, Pulse<V?>>(
            (pulse, {cell, user}) => transform(cell!, pulse, user: user)),
        postProcess: ValueCell.postProcessRule);
  }

  /// Retrieves the current state value held within this cell's physical storage.
  ///
  /// ### When to use
  /// This is the primary way to read the state synchronously.
  ///
  /// ### How it works
  /// It reads directly from the `Box`. For consistent reads across
  /// concurrent updates, use `await cell.async.state` instead.
  ///
  /// ### Example
  /// ```dart
  /// final counter = Cell.state<int>(state: 0);
  /// print(counter.cell.state); // 0
  /// ```
  V? get value => _nucleus.state.value;

  /// Assigns [value] through the same validated emission pipeline used by
  /// [Cell.state]'s update handle.
  ///
  /// Cross-package [ValueCell] implementations (e.g., `TissueValue`) provide
  /// their own setter; this public mutator lets generic machinery such as
  /// [Cell.transaction] commit buffered writes without reaching into the
  /// private `_emit`. Unmodifiable deputies reject the write silently.
  set value(V? value) {
    _emit(value);
  }

  bool _emit(V? v) {
    if (!identical(v, value) && v != value) {
      final receptor = _nucleus.receptor;
      final result = receptor.call(v == null ? Pulse<V>(null) : Pulse<V>(v));
      // The synchronous update contract can only report "accepted": an
      // async validation pipeline returns a Future here, and its committed
      // outcome is surfaced by ValueCellAsync._emit, which awaits the same
      // result (an async-rejected mutation must resolve false there).
      return result is Future<Pulse?> || result != null;
    }
    return false;
  }

  /// Returns a specialized asynchronous controller for this `ValueCell`,
  /// providing thread‑safe and serialized state access.
  ///
  /// ### When to use
  /// Use this when you need to read or update the state from an async
  /// context, or when you need to ensure consistency across concurrent
  /// operations.
  ///
  /// ### How it works
  /// It wraps the cell's operations in its internal [Lock], so reads and
  /// writes are serialized.
  ///
  /// ### Example
  /// ```dart
  /// final async = counter.cell.async;
  /// final current = await async.state; // waits for pending mutations
  /// await async._emit(10); // emit is private, but updateAsync is available
  /// ```
  @override
  ValueCellAsync<V> get async => ValueCellAsync<V>(this);

  /// Creates a governed projection of this cell that shares its state.
  ///
  /// Unlike the generic [CellBase.deputy], this returns a `ValueCell`-typed
  /// deputy so the value pipeline ([ValueCell.postProcessRule]) can keep
  /// committing to the shared [Box] and the deputy's own observers keep
  /// receiving updates. The deputy's rule is layered additively on top of
  /// this cell's rule — permissions can only narrow, never widen.
  @override
  FutureOr<ValueCell<V>> deputy({
    EphemeralPolicy? ephemeralPolicy,
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  }) {
    // Causal Integrity: the security context cannot escalate or bypass.
    // Runtime check — an `assert` disappears in release builds.
    if (context != DeputyContext.system &&
        this.context != DeputyContext.system &&
        context._parent != this.context) {
      throw StateError(
        'Causal Integrity Violation: The new DeputyContext must be a direct '
        'descendant of the current context.',
      );
    }

    // Identity Preservation: avoid a deputy of a deputy when no attenuation
    // is actually requested.
    final bool isAttenuationRequested = ephemeralPolicy != null ||
        !identical(context, DeputyContext.system) ||
        !identical(testRule, TestCell.allowAll) ||
        !identical(synapses, Synapses.enabled);

    if (!isAttenuationRequested) {
      return this;
    }

    return _ValueCellDeputy<V>(
      this,
      context: context,
      testRule: testRule,
      ephemeralPolicy: ephemeralPolicy,
      synapses: synapses,
    );
  }

  /// Generates a read‑only proxy of this cell that cannot be mutated.
  ///
  /// ### When to use
  /// Use this when you need to share the cell's state with components that
  /// should not be able to change it – e.g., UI widgets, external observers.
  ///
  /// ### How it works
  /// It creates a deputy with `TestCell.readOnly` – any attempt to mutate
  /// will be blocked by the integrity gate.
  ///
  @override
  ValueCell<V> get unmodifiable => UnmodifiableValueCell<V>._(this);

  @override
  String toString() => 'ValueCell<$V>($value)';
}

/// A specialized read‑only proxy of a `ValueCell` that enforces immutability.
///
/// This is what you get from `ValueCell.unmodifiable`. It blocks any
/// mutation attempts while still being a live, reactive participant in the
/// graph.
///
/// ### When to use
/// You get this automatically via `unmodifiable`. You don't construct it
/// directly.
///
/// ### How it works
/// It shares the same `Box` and lock as the principal, but its `testRule`
/// is set to `TestCell.readOnly`, so any mutation is rejected.
///
class UnmodifiableValueCell<V> extends ValueCell<V> implements Unmodifiable {
  UnmodifiableValueCell._(ValueCell<V> bind)
      : super.fromNucleus(
            // Evolve (not clone) so the projection LINKS to the principal
            // cell as its upstream: a bare `fromNucleus(bind._nucleus)` on an
            // already-activated nucleus clones it with the principal's own
            // (usually null) `bind`, leaving the projection an island whose
            // observers never hear about principal mutations. `evolve` also
            // resolves state through the principal chain — the projection
            // shares the principal's Box, exactly like `_ValueCellDeputy`.
            ValueNucleus<V>.evolve(principal: bind._nucleus, bind: bind));

  /// Layers `TestCell.readOnly` atop the principal's integrity gate.
  ///
  /// Because this projection shares the principal's nucleus (and therefore
  /// its Box, lock, and receptor), the only safe place to install the
  /// read-only enforcement is on the `validate` seam. `CellBase.apply`
  /// consults `validate.action(...)`, which now sees
  /// `chain([principal.testRule, readOnly])` and rejects any call to a
  /// whitelisted function (i.e. `apply` itself).
  ///
  /// Cached (`late final`) because `TestCell.chain` allocates a fresh record.
  @override
  late final TestCell validate =
      TestCell<Cell>.chain([_nucleus.testRule, TestCell.readOnly]);

  /// Rejects direct state mutation on the projection.
  ///
  /// The inherited `_emit` path calls the shared receptor directly and
  /// bypasses `validate`, so the setter must be sealed explicitly. This is
  /// intentionally *loud* (throws, matching `UnmodifiableListView`) rather
  /// than silently ignoring the write — the caller's intent is almost
  /// certainly a bug.
  @override
  set value(V? value) {
    throw UnsupportedError(
      'UnmodifiableValueCell: cannot assign `value` on a read-only '
      'projection. Mutate the principal returned by `Cell.state(...).cell`.',
    );
  }

  /// Retrieves the current state, projecting any nested `Cell` as
  /// unmodifiable.
  ///
  /// This ensures deep immutability – if the state is itself a `Cell`, it
  /// returns `state.unmodifiable`.
  @override
  V? get value {
    final state = _nucleus.state.value;
    if (state != null) {
      if (state is Cell) {
        return state.unmodifiable as V?;
      }
    }
    return state;
  }

  /// Returns itself – it's already the most restrictive view.
  @override
  ValueCell<V> get unmodifiable => this;

  /// Returns itself for any parameter set.
  ///
  /// An unmodifiable projection cannot be "deputized" into anything more
  /// permissive: the inherited [ValueCell.deputy] would build a
  /// [_ValueCellDeputy] with a working `value` setter, which is a mutable
  /// escape hatch around this read-only view.
  @override
  FutureOr<ValueCell<V>> deputy({
    EphemeralPolicy? ephemeralPolicy,
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  }) =>
      this;
}

/// A [ValueCell]-typed deputy that shares its principal's [Box], lock, and
/// transformation pipeline while layering its own additive [TestCell].
///
/// The generic `_CellDeputy` cannot host the value pipeline:
/// [ValueCell.postProcessRule] requires a `ValueCell`-typed host to commit to
/// the shared storage. This class keeps that contract so a read-only deputy
/// still receives principal mutations and re-broadcasts them to its own
/// observers.
class _ValueCellDeputy<V> extends ValueCell<V> with Deputy<ValueCell<V>> {
  _ValueCellDeputy(
    ValueCell<V> bind, {
    DeputyContext context = DeputyContext.system,
    TestCell testRule = TestCell.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  })  : _layered = testRule,
        super.fromNucleus(ValueNucleus<V>._((
          local: NucleusBase.mask(
            bind: bind,
            context: identical(context, DeputyContext.system) ? null : context,
            testRule: identical(testRule, TestCell.allowAll)
                ? null
                : TestCell<Cell>.chain([
                    bind._nucleus.testRule,
                    testRule,
                  ]),
            // No local `others` record: `state` then resolves through the
            // principal chain to the SHARED Box.
            synapses: synapses,
            ephemeralPolicy: ephemeralPolicy,
          ),
          principal: bind._nucleus,
        )));

  /// The rule this deputy layered on top of its principal — kept separately
  /// because [TestCell.chain] folds it into an opaque composite whose
  /// internal list is not exposed by [_parent] walking.
  final TestCell _layered;

  static bool _derivesReadOnly(TestCell<Cell>? rule) {
    while (rule != null) {
      if (identical(rule, TestCell.readOnly)) return true;
      rule = rule._parent;
    }
    return false;
  }

  bool get _isReadOnlyDeputy =>
      _derivesReadOnly(_layered) ||
      _derivesReadOnly(_nucleus.testRule);

  /// Exposes the principal's whitelist plus this deputy's own `apply`
  /// gateway, so principal-whitelisted commands are vetted through the FULL
  /// additive chain instead of the trusted unvetted path.
  @override
  Iterable<Function> get modifiable => {
        ..._nucleus.bind!.modifiable,
        apply<dynamic>,
      };

  @override
  FutureOr<ValueCell<V>> deputy({
    EphemeralPolicy? ephemeralPolicy,
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  }) {
    // Causal Integrity: the security context cannot escalate or bypass.
    // Runtime check — an `assert` disappears in release builds.
    if (context != DeputyContext.system &&
        this.context != DeputyContext.system &&
        context._parent != this.context) {
      throw StateError(
        'Causal Integrity Violation: The new DeputyContext must be a direct '
        'descendant of the current context.',
      );
    }

    // Identity Preservation: avoid a deputy of a deputy when no attenuation
    // is actually requested.
    final bool isAttenuationRequested = ephemeralPolicy != null ||
        !identical(context, DeputyContext.system) ||
        !identical(testRule, TestCell.allowAll) ||
        !identical(synapses, Synapses.enabled);

    if (!isAttenuationRequested) {
      return this;
    }

    return _ValueCellDeputy<V>(
      this,
      context: context,
      testRule: testRule,
      ephemeralPolicy: ephemeralPolicy,
      synapses: synapses,
    );
  }

  /// Seals the direct-write path when the layered rule derives from
  /// [TestCell.readOnly].
  ///
  /// The inherited [ValueCell.value] setter emits through the SHARED
  /// principal receptor, which validates against the principal's `validate`
  /// — not this deputy's additive chain. A read-only deputy therefore has
  /// to be sealed explicitly, exactly like [UnmodifiableValueCell].
  @override
  set value(V? value) {
    if (_isReadOnlyDeputy) {
      throw UnsupportedError(
        'ValueCell deputy: cannot assign `value` through a read-only '
        'deputy. Mutate the principal cell instead.',
      );
    }
    _emit(value);
  }
}
