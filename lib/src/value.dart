// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell.dart';

/// A management record that bundles a [ValueCell] with its imperative update
/// functions — the standard way to create and interact with a state atom.
///
/// ### When to use
/// You get this from [Cell.state]. It gives you:
/// - `cell`: the reactive state container (read‑only observation).
/// - `update`: a synchronous function to update the state.
/// - `emitAsync`: an asynchronous, lock‑protected version of `emit`.
/// - `ingest`: a low‑level entry point for full [Pulse] injection.
///
/// ### How it works
/// The handle separates the observable cell (safe to share) from the
/// mutation functions (keep them private to the owner). This enforces a
/// strict write‑privilege model – observers can only read, the owner can
/// write.
///
/// ### Non‑obvious
/// - `ingest` with `serializedCompletion: true` waits for the entire graph
///   to stabilise before the Future completes – useful for sequential
///   reasoning steps.
/// - `emitAsync` queues the mutation through the cell's [Lock], so it's
///   safe even under high concurrency.
///
/// ### Type Parameters:
/// * [V]: The type of the value managed by this state handle.
typedef StateHandle<V> = ({
  /// The persistent, observable reactive node.
  ValueCell<V> cell,

  /// Synchronously emits a state transition.
  /// Returns `true` if the value was successfully committed.
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
/// ### Non‑obvious
/// - The [forceLock] parameter in the primary constructor is `true` by
///   default (unlike the generic `Nucleus`), because state cells need their
///   own lock to prevent race conditions.
/// - When you `evolve` a `ValueNucleus`, the new nucleus shares the same
///   `Box` as its principal – no state duplication.
///
/// See also: [ValueCell], [Box], [Cell.state].
class ValueNucleus<V> extends NucleusBase {

  ValueNucleus._(super.record) : super.fromRecord();

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
  /// ### Non‑obvious
  /// - The initial `value` is written directly to the Box, bypassing the
  ///   transform – it's considered a trusted seed.
  /// - If `transform` is provided, it overrides the `receptor` parameter.
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
  ValueNucleus({
    Pulse<V>? Function(ValueCell<V> host, Pulse input, {dynamic user})? transform,

    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    EphemeralPolicy? ephemeralPolicy,

    Record? user,
    bool forceLock = true
  }) : this._((
  local: NucleusBase.mask(
      bind: bind, context: context, testRule: testRule, synapses: synapses,
      forceLock: forceLock, user: user, ephemeralPolicy: ephemeralPolicy,
      receptor: transform != null
          ? Receptor.pipeline(instruction: Instruction<ValueCell<V>,Pulse,Pulse<V>>((pulse, {cell, user, delayPropagation, token}) => transform(cell!, pulse, user: user)), postProcess: ValueCell.postProcessRule)
          : receptor == Receptor.passThrough ? Receptor.pipeline(postProcess: ValueCell.postProcessRule)  : receptor,
      others: (value: Box<V>())
  )
  )
  );

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
  /// ### Non‑obvious
  /// - If you omit the rule and provide a custom `receptor`, you must
  ///   ensure state commitment is handled.
  /// - The `forceLock` is set to `false` here (shared with principal),
  ///   unlike the primary constructor which forces a lock by default.
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
  ValueNucleus.from({
    Instruction<ValueCell<V>,Pulse,Pulse<V?>>? instruction,

    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    EphemeralPolicy? ephemeralPolicy,

    Record? user
  }) : this._((
      (local: NucleusBase.mask(bind: bind, context: context, testRule: testRule, synapses: synapses, forceLock: false, user: user,
          ephemeralPolicy: ephemeralPolicy,
          receptor: instruction != null ? Receptor.pipeline(instruction: instruction, postProcess: ValueCell.postProcessRule)
              : receptor == Receptor.passThrough ? Receptor.pipeline(postProcess: ValueCell.postProcessRule)  : receptor,
          others: (value: Box<V>()))
      ))
  );

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
  /// ### Non‑obvious
  /// - The `rule` (if provided) overrides the transformation logic, but the
  ///   `postProcess` (commitment) is still applied.
  /// - The lock is inherited from the principal unless the `override`
  ///   parameter is used.
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
  ValueNucleus.evolve({
    Instruction<ValueCell<V>,Pulse,Pulse<V?>>? instruction,

    EphemeralPolicy? ephemeralPolicy,
    Cell? bind,
    Context? context,
    Receptor? receptor,
    TestCell? testRule,
    Synapses? synapses,
    Record? user,

    ValueNucleus? override,
    required ValueNucleus principal
  }) : this._((
  local: override?.record.local ?? NucleusBase.mask(bind: bind,
      context: context,
      receptor: instruction != null ? Receptor.pipeline(instruction: instruction, postProcess: ValueCell.postProcessRule)
          : receptor == Receptor.passThrough ? Receptor.pipeline(postProcess: ValueCell.postProcessRule)  : receptor,
      testRule: testRule, synapses: synapses, user: user, ephemeralPolicy: ephemeralPolicy,
      others: (value: Box<V>())
  ),

  principal: principal
  ));

  /// Resolves the physical [Box] storage container that holds the current
  /// state.
  ///
  /// ### When to use
  /// You usually don't need this – use [ValueCell.value] instead.
  ///
  /// ### How it works
  /// The getter walks up the principal chain to find the root nucleus that
  /// originally allocated the `Box`. This ensures that all deputies share
  /// the same storage.
  Box<V> get value => get<Box<V>>(() => record.local.others.value, fallback: () => principal!.value, orElse: null);

  @override
  ValueNucleus<V>? get principal => super.principal as ValueNucleus<V>?;

  @override
  ValueNucleus get clone {
    final handle = inheritable;
    return ValueNucleus._((
    local: NucleusBase.mask(
      bind: handle.bind,
      context: handle.context,
      receptor: handle.receptor.clone,
      testRule: handle.testRule,
      ephemeralPolicy: handle.ephemeralPolicy,
      synapses: synapses != Synapses.disabled ? Synapses.enabled : Synapses.disabled,
      user: user,
      forceLock: lock != null,
    ),
    principal: principal
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
/// A `ValueCell` holds a value in a `Box` (physical storage). It uses a
/// [Receptor] to process incoming pulses through a `transform` function,
/// validates the result with a `testRule`, and commits the new value to
/// the `Box`. Changes are then broadcast to observers via [Synapses].
///
/// ### Non‑obvious
/// - The cell is thread‑safe – all mutations are serialized through its
///   internal [Lock].
/// - You can read the value synchronously with `cell.value`, but for
///   consistency across concurrent updates, use `await cell.async.value`.
/// - If you create a deputy via `deputy()`, it shares the same state but
///   can have its own validation or propagation rules.
///
/// See also: [Cell.state] (the factory), [ValueNucleus] (the blueprint),
/// [Box] (storage), [StateHandle] (the returned record).
/// {@category Core}
class ValueCell<V> extends CellBase {

  /// A static, reusable [Instruction] that commits a validated pulse to the
  /// cell's `Box`.
  ///
  /// This is the "commitment stage" of the pipeline. It's used internally
  /// by `ValueCell` and `ValueNucleus`. You don't need to call it directly.
  static Instruction postProcessRule =
  Instruction<ValueCell,Pulse,Pulse>((pulse, {cell, user}) {
    cell!._nucleus.value.value = pulse.payload;
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
  /// initial `value` directly into the `Box` (bypassing the transform).
  ///
  /// ### Non‑obvious
  /// - If you provide a custom `receptor` without a `transform`, you must
  ///   include `ValueCell.postProcessRule` manually, otherwise the state
  ///   won't be persisted.
  /// - The `bind` parameter creates a dependency – when the bound cell
  ///   changes, this cell automatically receives a pulse.
  ///
  /// ### Parameters:
  /// *   `transform`: **The Reactive Brain.** An optional functional unit
  ///     that defines the cell's "metabolism." It intercepts incoming stimuli,
  ///     performing sanitization, complex mapping, or type-safe transitions.
  ///     If `transform` returns `null`, the update is treated as a "noop" and
  ///     discarded; otherwise, the resulting [Pulse] is passed to the
  ///     commitment phase.
  /// *   `value`: **The Initial Seed.** An optional value of type [V?] that
  ///     establishes the cell's foundational state. This value is written
  ///     directly to the internal [Box] during the construction phase,
  ///     effectively setting the "Known Good" baseline before the cell
  ///     begins processing external signals or reactive waves.
  /// *   `bind`: **The Upstream Anchor.** An optional principal [Cell] that this
  ///     instance "watches" (observes). When the `bind` cell evolves, it
  ///     automatically emits this cell's `transform` pipeline, passing
  ///     the principal's latest state as the `bind` parameter. This is the
  ///     primary mechanism for creating **Dependent State** and maintaining
  ///     referential integrity across the graph.
  /// *   `context`: **The Operational Scope.** Defines the semantic metadata
  ///     and environmental "Tier" (defaulting to [Context.system]) in which
  ///     this cell operates. It governs auditing, AI-driven behavioral
  ///     gating (PII, GDPR), and synchronization boundaries within the
  ///     wider application ecosystem.
  /// *   `receptor`: **The Low-Level Gateway.** The underlying [Receptor] logic
  ///     responsible for ingesting signals. While typically managed
  ///     automatically by the `transform` pipeline, providing a custom
  ///     receptor allows for advanced behavioral overrides.
  ///     **Critical Operational Safety**:
  ///     - If a custom receptor is provided, it must manually integrate the
  ///       [ValueCell.postProcessRule] into its execution chain. This rule
  ///       handles the final **Metabolic Assimilation**: validating the
  ///       transduced value against the `testRule`, committing it to the
  ///       physical [Box], and emitting the secretion of the update.
  ///     - **Recommended Pattern**: Instead of manual configuration, use the
  ///       [ValueCell.receptor] static factory to synthesize a receptor
  ///       that is pre-integrated with the framework's commitment and
  ///       persistence protocols.
  /// *   `testRule`: **The Immune System.** A compositional [TestRule]
  ///     (defaulting to [TestCell.allowAll]) used to validate proposed state
  ///     changes. It acts as a final gatekeeper, ensuring that new values
  ///     satisfy domain constraints and security restrictions before they
  ///     are committed to the cell's storage.
  /// *   `synapses`: **The Propagation Engine.** Controls how this cell
  ///     communicates with downstream dependents. By default ([Synapses.enabled]),
  ///     it will broadcast signals whenever its internal state changes.
  ///     This can be configured with [PropagationPolicy] to manage temporal
  ///     behaviors like debouncing, throttling, or batching.
  ///
  /// ### Implementation Detail:
  /// This constructor delegates to [ValueCell.fromNucleus]. Internally, it
  /// initializes a [ValueNucleus] which ensures the [transform] logic is
  /// paired with the [ValueCell.postProcessRule] receptor. This creates the
  /// "Validated Commitment" flow: Input -> Transform -> Validate -> Persist.
  ValueCell({
    Pulse<V>? Function(ValueCell<V> host, Pulse input, {dynamic user, Cell? bind})? transform,
    V? value,

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
          synapses: synapses
      ), value: value
  );

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
  ///   value: 0,
  ///   transform: (host, input, {user}) => Pulse(host.value + 1),
  /// );
  /// // No observers will be notified of changes
  /// ```
  ValueCell.terminal({
    Pulse<V>? Function(ValueCell<V> host, Pulse input, {dynamic user, Cell? bind})? transform,
    V? value,

    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
  }) : this(synapses: Synapses.disabled,
      transform: transform, bind: bind, context: context, receptor: receptor, testRule: testRule
  );

  /// Initializes a [ValueCell] from an existing [ValueNucleus] – used
  /// internally for blueprint hydration.
  ///
  /// ### When to use
  /// This is used by the framework when you create a cell from a nucleus
  /// (e.g., when restoring from a saved state). You rarely call it yourself.
  ///
  /// ### How it works
  /// It binds the nucleus to the cell and optionally seeds an initial value
  /// directly (bypassing the transform).
  ///
  /// ### Non‑obvious
  /// - The initial value is written directly to the Box without validation.
  /// - The nucleus is cloned if it's already activated (to avoid sharing).
  ///
  /// ### Parameters:
  /// * [nucleus]: **Required.** The [ValueNucleus] that defines the behavior,
  ///   storage schema, and environmental [Context] for this cell.
  /// * [value]: An optional initial state of type [V?]. If provided, it
  ///   populates the cell's storage immediately, overwriting any
  ///   previous data in the nucleus's associated [Box].
  ///
  /// ### Returns:
  /// A fully hydrated [ValueCell] instance ready for reactive interaction.
  ValueCell.fromNucleus(ValueNucleus<V> super.nucleus, {V? value}) : super.fromNucleus() {
    if (value != null) {
      _nucleus.value.value = value;
    }
  }

  /// A high-level static factory that synthesizes a [ValueCell] and its
  /// operational [StateHandle] in a single atomic operation.
  ///
  /// ### When to use
  /// - **Internal Engine**: The primary factory behind [Cell.state]. You rarely
  ///   need to call this directly.
  /// - **Custom Abstractions**: Use this when building specialized [Cell]
  ///   types that require manual [ValueNucleus] hydration while exposing
  ///   standard imperative handles.
  ///
  /// ### How it works
  /// 1. **Hydration**: Instantiates a [ValueCell] from the [nucleus] blueprint.
  /// 2. **Seeding**: Writes the initial [value] directly to storage, bypassing
  ///    the transformation pipeline.
  /// 3. **Handle Synthesis**: Creates a suite of closures (`update`,
  ///    `updateAsync`, `ingest`) that bridge imperative calls to the cell's
  ///    internal [Receptor].
  ///
  /// ### Non‑obvious
  /// - **Instance Binding**: Handles are permanently bound to the specific
  ///   cell instance; they cannot be reassigned or used with other cells.
  /// - **Graph Stabilization**: The `ingest` handle defaults to
  ///   `serializedCompletion: true`, meaning the [Future] only resolves once
  ///   the *entire* downstream reactive chain has settled.
  ///
  /// ### Parameters:
  /// * [nucleus]: The blueprint defining the cell's identity, transformation
  ///   logic, and security context.
  /// * [value]: An optional initial value to seed the cell's storage. This
  ///   bypasses the transformation pipeline and is applied immediately.
  ///
  /// ### Returns:
  /// A [StateHandle] containing the `cell` and its associated mutation
  /// primitives (`update`, `updateAsync`, and `ingest`).
  ///
  /// ### See Also:
  /// - [Cell.state]: The standard application-level API for state creation.
  /// - [ValueNucleus]: The underlying blueprint used to configure this factory.
  /// - **HowTo**: See `guide/HowTo_Start.md` for a guide on state management
  ///   and using handles.
  static StateHandle<V> create<V>(
      ValueNucleus<V> nucleus, {V? value}) {
    final cell = ValueCell<V>.fromNucleus(nucleus, value: value);
    final valueCellAsync = ValueCellAsync<V>(cell);
    final receptor = nucleus.receptor;

    Future<void> ingest(Pulse<V> pulse, {bool serializedCompletion = true}) {
      return receptor.async.call(pulse as PulseBase, serializedCompletion: serializedCompletion);
    }

    return (cell: cell, update: cell._emit, updateAsync: valueCellAsync._emit, ingest: ingest);
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
  /// final cell = ValueCell<int>(value: 0, receptor: receptor);
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
  static Receptor receptor<V>(Pulse<V?>? Function(ValueCell<V> host, Pulse input, {dynamic user}) transform) {
    return Receptor.pipeline(
        instruction: Instruction<ValueCell<V>,Pulse,Pulse<V?>>((pulse, {cell, user}) => transform(cell!, pulse, user: user)),
        postProcess: ValueCell.postProcessRule
    );
  }

  /// Retrieves the current state value held within this cell's physical storage.
  ///
  /// ### When to use
  /// This is the primary way to read the state synchronously.
  ///
  /// ### How it works
  /// It reads directly from the `Box`. For consistent reads across
  /// concurrent updates, use `await cell.async.value` instead.
  ///
  /// ### Example
  /// ```dart
  /// final counter = Cell.state<int>(value: 0);
  /// print(counter.cell.value); // 0
  /// ```
  V? get value => _nucleus.value.value;

  bool _emit(V? v) {
    if (!identical(v, value) && v != value) {
      final receptor = _nucleus.receptor;
      return receptor.call(v == null ? Pulse<V>(null) : Pulse<V>(v)) != null;
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
  /// final current = await async.value; // waits for pending mutations
  /// await async._emit(10); // emit is private, but emitAsync is available
  /// ```
  @override
  ValueCellAsync<V> get async => ValueCellAsync<V>(this);

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
  /// ### Non‑obvious
  /// - The read‑only view still broadcasts changes to its own observers.
  /// - It shares the same state and lock as the principal.
  /// - `cell == cell.unmodifiable` is `true`.
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
/// ### Non‑obvious
/// - It recursively projects nested `Cell` values as unmodifiable.
/// - It is logically equal to its principal (`==` is `true`).
///
/// See also: [ValueCell.unmodifiable].
class UnmodifiableValueCell<V> extends ValueCell<V> implements Unmodifiable {

  UnmodifiableValueCell._(ValueCell<V> bind)
      : super.fromNucleus(bind._nucleus);

  /// Retrieves the current state, projecting any nested `Cell` as
  /// unmodifiable.
  ///
  /// This ensures deep immutability – if the value is itself a `Cell`, it
  /// returns `value.unmodifiable`.
  @override
  V? get value {
    final value = _nucleus.value.value;
    if (value != null) {
      if (value is Cell) {
        return value.unmodifiable as V?;
      }
    }
    return value;
  }

  /// Returns itself – it's already the most restrictive view.
  @override
  ValueCell<V> get unmodifiable => this;

}