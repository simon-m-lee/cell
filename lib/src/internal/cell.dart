// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell.dart';

/// Base class for all [OpenCell] types.
typedef OpenCellBase = _OpenCell;

/// A management handle for an **Input Gateway**, providing a controlled
/// interface for injecting external imperative stimuli into the reactive graph.
///
/// In the Cell architecture, an [IngressHandle] serves as the
/// **Imperative-to-Reactive Bridge**. It provides the primary mechanism for
/// non-reactive components—such as UI event handlers, hardware sensors, or
/// network callbacks—to initiate state transitions within a synchronized,
/// **Scene-Driven Ontology**.
///
/// ### When to use
/// You get this from [Cell.ingress]. Use it when you need to inject external
/// events (like button clicks, WebSocket messages, or sensor readings) into
/// the reactive graph.
///
/// ### How it works
/// The handle wraps a cell and provides three ways to send data:
/// - `emit`: synchronous, immediate update.
/// - `emitAsync`: asynchronous, lock-protected update.
/// - `ingest`: full [Pulse] injection with provenance.
///
/// ### Non‑obvious
/// - If the cell has a [Lock] (via `forceLock: true`), `emitAsync` queues
///   the update to prevent race conditions.
/// - The `ingest` method with `serializedCompletion: true` waits for the
///   entire graph to stabilise before the Future completes.
///
/// ### Type Parameters:
/// * [I]: The raw input data type accepted by this gateway.
typedef IngressHandle<I> = ({

  /// The source node ("cell") that anchors this entry point to the graph.
  Cell cell,

  /// Emits a raw stimulus into the reactive graph at **Native Speed**.
  ///
  /// This is the most common way to bridge imperative code (like UI events)
  /// into the reactive fabric. The handle automatically wraps the [input]
  /// in a [Pulse] and initiates the **Ingress Phase**.
  ///
  /// Returns `true` if the signal successfully passed the **Integrity Gate**.
  bool Function(I input) emit,

  /// Asynchronously emits a stimulus, ensuring **Serialized Transformation**
  /// through the node's **Conactive Lock**.
  ///
  /// Use this when you need to ensure that the update respects the system's
  /// atomic boundaries, preventing race conditions in high-concurrency scenes.
  Future<bool> Function(I input) emitAsync,

  /// The **Primary Ingress Handle** for direct **Signal Orchestration**.
  ///
  /// Unlike [emit], which takes raw data, [ingest] accepts a fully-formed
  /// [Pulse]. Use this when you need to provide specific **Provenance**
  /// (like a custom `justification` or `traceId`).
  Future<void> Function(Pulse<I> pulse, {bool serializedCompletion}) ingest
});

/// A management handle for a **Signal Distribution Hub**, providing a unified
/// interface to control a multi-destination routing cluster.
///
/// ### When to use
/// You get this from [Cell.hub]. Use it when you need to fan‑out a single
/// pulse to multiple specialised handlers based on [Pulse.type].
///
/// ### How it works
/// The handle contains a `root` cell (the ingress) and a set of `spokes`
/// (the handlers). When you `emit` or `ingest` a pulse, it's routed to
/// the appropriate spoke(s) based on the hub's configuration.
///
/// ### Non‑obvious
/// - If you provide a custom `relay`, the default routing is bypassed – you
///   must manually deliver pulses to the spokes.
/// - The hub's `ingest` with `serializedCompletion: true` waits for all
///   spokes to finish processing before completing the Future.
typedef HubHandle = ({
  /// The central ingress node that governs the distribution hub. This node
  /// acts as the central gateway and **Integrity Gate** for the cluster.
  Cell root,

  /// The collection of specialized downstream nodes (branches) that
  /// receive signals fanned out from the [root].
  Iterable<Cell> spokes,

  /// Synchronously injects a [Pulse] into the hub's [root] at **Native Speed**.
  ///
  /// Returns the resulting pulse if it successfully passed the **Integrity
  /// Gate** and was broadcast; returns `null` if neutralized by a policy guard.
  Pulse? Function(Pulse pulse) emit,

  /// Asynchronously injects a stimulus, ensuring **Serialized Transformation**
  /// through the system's **Conactive Lock**.
  ///
  /// This modality is required if the [root] or any [spokes] involve
  /// I/O-bound validation or cross-domain security checks.
  Future<Pulse?> Function(Pulse pulse) emitAsync,

  /// The **Primary Distribution Ingress** handle.
  ///
  /// This handle is the "Entry Port" for the switching fabric. It is used
  /// to introduce a single [Pulse] that will be demultiplexed across
  /// all registered `spokes` according to the hub's [manifest].
  ///
  /// ### The Consequence of [serializedCompletion]:
  /// This parameter defines the **Convergent Boundary** for the fan-out
  /// operation:
  ///
  /// *   **Synchronous Convergence (`true`)**: The returned [Future] will
  ///     only resolve once the signal has propagated through the root AND
  ///     all associated spokes have finished their transformations. This
  ///     guarantees that the entire **Collection** has stabilized before
  ///     the caller proceeds.
  /// *   **Parallel Propagation (`false`)**: The [Future] resolves once the
  ///     signal is safely enqueued at the `root`. The distribution to
  ///     spokes happens as a background task, maximizing throughput for
  ///     high-frequency telemetry or logging scenes.
  Future<void> Function(Pulse pulse, {bool serializedCompletion}) ingest

});

/// A management handle for an **Output Terminal**, providing a controlled
/// interface to manage an external side-effect listener.
///
/// ### When to use
/// You get this from [Cell.observe]. Use it when you need to react to
/// state changes with side effects – e.g., updating the UI, logging, or
/// sending a network request.
///
/// ### How it works
/// The handle contains a terminal cell that receives pulses from its
/// `bind` source. You can `start` or `stop` the observer to enable/disable
/// side effect execution.
///
/// ### Non‑obvious
/// - The cell is terminal – it never propagates pulses further.
/// - `stop` doesn't remove the cell from the graph; it just pauses
///   side effect execution.
typedef EgressHandle<S extends Pulse> = ({
  /// The terminal node (`cell`) that anchors this side-effect point to the graph.
  Cell cell,

  /// Enables the terminal node, allowing incoming signals to emit side effects.
  void Function() start,

  /// Disables the terminal node, halting all external side effects while
  /// maintaining its position in the graph.
  void Function() stop
});

/// A specialized architectural marker and base interface for objects that support
/// controlled mutation through the framework's dynamic command pattern.
///
/// [Modifiable] serves as a foundational component of the cell's security
/// and reactive architecture, defining the formal contract for **Mutation
/// Entry Points**—specific operations permitted to alter the state or
/// structural topology of a node.
///
/// ### When to use
/// - **Custom Components**: Use when building custom reactive nodes that
///   require internal state changes without exposing public mutable fields.
/// - **Access Control**: Use to define the boundary between a mutable
///   principal and its read-only views or deputies.
/// - **Whitelisting**: Use to explicitly define which internal methods are
///   safe to trigger from external reactive stimuli.
///
/// ### How it works
/// 1. **Command Pattern**: Works with [Cell.apply] to facilitate a decoupled
///    execution gateway, allowing actions to be emitted on a node without
///    compile-time knowledge of its concrete type.
/// 2. **Whitelisting**: Subclasses explicitly register a map of permitted
///    methods. Only these "Whitelisted Operations" can be triggered via
///    the command gateway.
/// 3. **Integrity Gating**: Every mutation request is validated by a
///    [TestCell] to ensure the caller has sufficient authority.
/// 4. **Atomicity**: All state transitions are automatically wrapped in a
///    synchronization [Lock] to prevent "torn states" in high-frequency
///    reactive waves.
///
/// ### Non‑obvious
/// - **Zero-Cost Immutability**: By returning an empty whitelist, an
///   object becomes effectively immutable while remaining a first-class
///   member of the reactive graph.
/// - **Proxying Infrastructure**: It provides the base logic needed for
///   [Cell.deputy] to intercept and delegate calls safely.
/// - **Flyweight Architecture**: The use of a `const` constructor allows
///   the system to manage unmodifiable views with minimal heap pressure.
/// - **State Isolation**: Subclasses are responsible for ensuring that
///   modifications trigger the appropriate reactive pulses to maintain graph
///   consistency.
///
/// ### See Also:
/// * [Cell.apply]: The primary method for executing commands on a
///   [Modifiable] instance.
/// * [TestCell]: The security validator for mutation requests.
/// * [Nucleus]: The blueprint that often manages the state targeted by
///   these modifications.
class Modifiable {
  /// Internal constant constructor for [Modifiable].
  ///
  /// Being a `const` constructor allows subclasses to remain memory-efficient
  /// and supports the framework's **Flyweight Architecture**. It enables
  /// the creation of immutable "Unmodifiable" views that effectively
  /// disable [Modifiable] capabilities by returning empty whitelists
  /// without requiring additional heap allocations.
  const Modifiable();
}


class _Cell extends CellBase {

  _Cell({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,

    bool forceLock = false,
  }) : this.fromNucleus(Nucleus(ephemeralPolicy: ephemeralPolicy,
      receptor: receptor, bind: bind, testRule: testRule, context: context,
      synapses: synapses == Synapses.enabled ? Synapses() : synapses,
      forceLock: forceLock
  ));

  _Cell.fromNucleus(super.evolve) : super.fromNucleus();

}

/// The foundational abstract implementation of the [Cell] interface.
///
/// `CellBase` provides the essential plumbing for a reactive cell, handling
/// state storage, graph connection initialization, and the command execution
/// lifecycle. It serves as the backbone for concrete cell implementations,
/// reducing boilerplate code.
///
/// ### When to use
/// You don't use this directly – it's the base class for all concrete
/// [Cell] implementations. Subclasses like `_Cell`, `_OpenCell`, and
/// `SynthesisCell` extend it.
///
/// ### How it works
/// - It holds a [Nucleus] (the immutable blueprint).
/// - On creation, it automatically links to any `bind` upstream cell.
/// - It implements `apply` with validation via the [TestCell].
/// - Equality (`==`) and `hashCode` are based on the root principal, so
///   deputies are equal to their principals.
///
/// ### Non‑obvious
/// - The `fromNucleus` constructor clones the nucleus if it's already
///   activated, preventing two cells from sharing the same lock.
/// - Auto‑wiring to `bind` happens in a `try` block – if linking fails,
///   the cell still initialises to maintain graph availability.
///
/// Subclasses extend this to define specific behavior while relying on this
/// class for standard interface compliance.
abstract class CellBase implements Cell {

  @override
  final Nucleus _nucleus;

  /// Initializes a new cell instance with specific behaviors and connections.
  ///
  /// This constructor sets up the internal state ([Nucleus]) of the cell. It
  /// acts as the primary entry point for subclasses to define their configuration.
  ///
  /// - [bind]: An optional upstream [Cell] that this cell acts as a deputy for.
  /// - [context]: The execution context (e.g., system vs user).
  /// - [receptor]: The logic unit responsible for transforming incoming signals.
  /// - [testRule]: The validation rule determining permissions for this cell.
  /// - [synapses]: The manager for downstream connections. If [Synapses.enabled]
  ///   is passed (default), a new [Synapses] instance is created.
  CellBase({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : this.fromNucleus(Nucleus(ephemeralPolicy: ephemeralPolicy,
      receptor: receptor, bind: bind, testRule: testRule, context: context,
      synapses: synapses == Synapses.enabled ? Synapses() : synapses
  ));

  /// Initializes a [CellBase] instance using a pre-configured [Nucleus]
  /// blueprint, formally integrating it into the reactive data-flow graph.
  ///
  /// This named constructor is the primary **Hydration Engine** for the
  /// framework. While standard constructors are used for fresh instances,
  /// `fromNucleus` is utilized for advanced architectural scenarios such
  /// as state restoration, prototype-based cloning (via `evolve`), and
  /// the instantiation of specialized [Deputy] proxies.
  ///
  /// ### 1. Purpose: Transition from Template to Node
  /// In the framework's **Flyweight Architecture**, a [Nucleus] often exists
  /// as a stateless template or "DNA." This constructor performs the
  /// critical transition of "Re-animating" that template into a live,
  /// stateful execution node:
  /// 1.  **Flyweight Isolation**: It inspects the [nucleus]. If the
  ///     provided nucleus is already **activated** (bound to another cell),
  ///     the constructor automatically generates a **Decoupled Copy**.
  ///     This prevents "State Bleeding" where two distinct cells
  ///     accidentally share the same synchronization lock or observer list.
  /// 2.  **Lifecycle Activation**: It invokes the nucleus's internal
  ///     activation sequence, notifying the underlying property record
  ///     that it now governs this specific cell instance.
  ///
  /// ### 2. Automated DAG Wiring (Self-Registration)
  /// Upon invocation, this constructor performs critical **Self-Wiring**
  /// logic to maintain the integrity of the **Directed Acyclic Graph (DAG)**:
  /// *   **Upstream Discovery**: It queries the nucleus for an upstream
  ///     [bind] target (the "Principal").
  /// *   **Reactive Linking**: If a principal is found, the constructor
  ///     automatically registers this new cell as a downstream observer
  ///     within the principal's [synapses]. This ensures that a new
  ///     deputy or child node is immediately synchronized with its source
  ///     upon birth.
  ///
  /// ### 3. Conactivity & Resilience
  /// The initialization process is designed to be **Conactive**. The
  /// auto-wiring logic is wrapped in a guarded block to ensure that if
  /// a complex relational binding fails (e.g., due to a temporary
  /// synchronization lock conflict during a high-frequency reactive wave),
  /// the system continues to initialize the cell to maintain graph
  /// availability.
  ///
  /// ### 4. Usage in Custom Factories
  /// This constructor is the intended target for high-level factory methods
  /// (like `OpenCell.perform` or `ValueCell.create`) that need to
  /// instantiate specialized cells from shared logic templates.
  ///
  /// ### Parameters:
  /// - [nucleus]: The [Nucleus] record defining the behavioral logic,
  ///   synchronization lock, execution [context], and relational links
  ///   for this cell.
  CellBase.fromNucleus(Nucleus nucleus) : _nucleus = nucleus.isActivated ? nucleus.clone : nucleus {
    try {
      _nucleus.activate(this);
      final bind = nucleus.bind;
      if (bind != null) {
        final synapses = bind._nucleus.synapses;
        synapses.link(bind, downstreamCell: this);
      }
    } catch(_) {}
  }

  @override
  FutureOr<Cell> deputy({
    EphemeralPolicy? ephemeralPolicy,
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled
  }) {
    return (ephemeralPolicy != null || context != DeputyContext.system || testRule != TestCell.allowAll || synapses != Synapses.enabled)
        ? _CellDeputy(bind: this, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses)
        : this;
  }

  @override
  TestCell get validate => _nucleus.testRule;

  @override
  Context get context => _nucleus.context;

  /// Returns a hash code for this [Cell] derived from its **Root Genotypic Identity**.
  ///
  /// ### When to use
  /// You don't call this directly – it's automatic. It ensures that deputies
  /// and principals have the same hash code, so they work correctly in
  /// [Map]s and [Set]s.
  ///
  /// ### How it works
  /// The hash is resolved by traversing up the principal chain to the root
  /// nucleus. This guarantees `principal.hashCode == deputy.hashCode`.
  ///
  /// ### Non‑obvious
  /// This is what makes deputies and principals interchangeable in collections.
  @override
  int get hashCode => _nucleus.hashCode;

  /// Determines logical identity between two [Cell] nodes within the reactive graph.
  ///
  /// ### When to use
  /// Automatic – you don't call this directly. It ensures that deputies are
  /// equal to their principals.
  ///
  /// ### How it works
  /// - Two deputies are equal if they point to the same underlying cell.
  /// - A deputy is equal to its principal.
  /// - Two distinct mutable cells are only equal if they share the same
  ///   physical identity.
  ///
  /// ### Non‑obvious
  /// This is why `cell == cell.deputy()` is `true`. It's based on the
  /// principal identity, not the object reference.
  @override
  bool operator ==(Object other) {
    // 1. Instant Identity Check (Same memory address)
    if (identical(other, this)) return true;

    // 2. Type Check (Must be part of the Cell organism ecosystem)
    if (other is! Cell) return false;

    return _nucleus == other._nucleus;

  }

  @override
  // dynamic apply(Function function, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]) {
  dynamic apply(
      Function function,
  {List? positionalArguments,
      Map<Symbol, dynamic>? namedArguments,

        ApplyTransactionScope? tx,
        Function? compensate,
        List? compensatePositional,
        Map<Symbol, dynamic>? compensateNamed,
        Cell? compensateCell,
      }) {

    if (tx != null) {
      tx.enqueue(
        this,
        function,
        positionalArguments,
        namedArguments,
        compensateCell: compensateCell,
        compensateFunction: compensate,
        compensatePositional: compensatePositional,
        compensateNamed: compensateNamed,
      );
      return null;
    }

    if (modifiable.contains(function)) {
      // 1. Capture the FutureOr validation result from the Integrity Gate
      final validation = _nucleus.testRule.action(
          function,
          host: this,
          arguments: (positionalArguments: positionalArguments, namedArguments: namedArguments)
      );

      // 2. Branch: Asynchronous Path
      if (validation is Future<bool>) {
        return validation.then((passed) {
          if (passed) {
            return Function.apply(function, positionalArguments, namedArguments);
          }
          return null; // Action blocked by policy
        });
      }

      // 3. Branch: Synchronous Path (Zero-cost check)
      if (!validation) return null;
    }

    // Standard execution for sync path or non-modifiable functions
    return Function.apply(function, positionalArguments, namedArguments);
  }


  @override
  Iterable<Function> get modifiable => <Function>{apply};

  @override
  bool get isTerminal => _nucleus.synapses == Synapses.disabled;

  @override
  Cell get unmodifiable => this;

  @override
  ModifiableAsync<Cell> get async => ModifiableAsync<Cell>(this);

  @override
  bool get isInvalidated => _nucleus.isInvalidated;

  @override
  bool get isGoverned => _nucleus.isGoverned;

  @override
  String toString() => '$runtimeType($hashCode)';

}

/// Represents a **Synthesis Cell**—a specialized structural node that aggregates
/// signals from multiple source cells into a single unified stream.
///
/// The [SynthesisCell] is the framework's primary mechanism for **Information
/// Convergence**. It allows the reactive graph to treat a set of disparate
/// [Cell] instances as a single logical unit, ensuring that the system can
/// reason about a "Whole" composed of many "Parts."
///
/// ### When to use
/// Use this when you need to combine multiple sources into one – e.g.,
/// sensor fusion, state aggregation, or combining UI controls. You typically
/// create one via [Cell.synthesis].
///
/// ### How it works
/// The synthesis cell observes a list of upstream cells. When any of them
/// emits a pulse, the cell's `aggregator` function is called with the full
/// list of sources and the emitting pulse. The aggregator returns a new
/// pulse (or `null` to drop it).
///
/// ### Non‑obvious
/// - The synthesis cell does not store state – it's a pure transform.
/// - The aggregator is called for every pulse from any source.
/// - The cell automatically links to all provided sources on construction.
class SynthesisCell extends CellBase with IterableMixin<Cell> implements Iterable<Cell> {

  final Set<Cell> _sources;

  /// Creates a [SynthesisCell] that binds to the provided [cells].
  ///
  /// Parameters:
  /// * [cells]: The [Iterable] of source [Cell] instances to be aggregated.
  /// * [ephemeralPolicy]: Defines the **Lifecycle Governance** (TTL/Cleanup).
  /// * [bind]: An optional root principal if this collective is a deputy view.
  /// * [context]: The **Scene-Driven Ontology** (Authority Tier) of this node.
  /// * [receptor]: The logic used to transform input pulses into the
  ///   collective payload.
  /// * [testRule]: The **Integrity Gate** that enforces system policy.
  /// * [synapses]: The **Signal Distribution Hub** for downstream propagation.
  /// * [forceLock]: If `true`, ensures the creation of an **Atomic
  ///   Transaction Domain** via a mandatory [Lock], preventing race conditions
  ///   during multi-source ingestion.
  SynthesisCell(Iterable<Cell> cells, {
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    bool forceLock = false
  }) : _sources = cells.toSet(), super.fromNucleus(Nucleus(
    ephemeralPolicy: ephemeralPolicy,
    testRule: testRule,
    receptor: receptor,
    bind: bind,
    context: context,
    synapses: synapses == Synapses.enabled ? Synapses() : synapses,
    forceLock: forceLock
  )) {
    for (var c in cells) {
      c._nucleus.synapses.link(c, downstreamCell: this);
    }
  }

  static SynthesisHandle handle(Iterable<Cell> cells, {
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    bool forceLock = false
  }) {
    // 1. Maintain a local set of sources to track membership
    final sourceSet = Set<Cell>.from(cells);

    // 2. Instantiate the Synthesis Cell (constructor links initial cells)
    final cel = SynthesisCell(sourceSet,
        ephemeralPolicy: ephemeralPolicy,
        bind: bind,
        context: context,
        receptor: receptor,
        testRule: testRule,
        synapses: synapses,
        forceLock: forceLock
    );

    // 3. Define the manipulation logic
    bool add(Cell c) {
      if (sourceSet.add(c)) {
        c._nucleus.synapses.link(c, downstreamCell: cel);
        return true;
      }
      return false;
    }

    bool remove(Cell c) {
      if (sourceSet.remove(c)) {
        c._nucleus.synapses.unlink(c, downstreamCell: cel);
        return true;
      }
      return false;
    }

    void addAll(Iterable<Cell> cs) => cs.forEach(add);
    void removeAll(Iterable<Cell> cs) => cs.forEach(remove);
    List<Cell> toList() => sourceSet.toList(growable: false);

    bool clear() {
      for (var c in sourceSet) {
        c._nucleus.synapses.unlink(c, downstreamCell: cel);
      }
      sourceSet.clear();
      return true;
    }

    // Stop/Start controls the propagation by unlinking/re-linking the entire set
    void stop() {
      for (var c in sourceSet) {
        c._nucleus.synapses.unlink(c, downstreamCell: cel);
      }
    }

    void start() {
      for (var c in sourceSet) {
        c._nucleus.synapses.link(c, downstreamCell: cel);
      }
    }

    // 4. Return the SynthesisHandle record
    return (
      cell: cel,
      add: add,
      remove: remove,
      addAll: addAll,
      removeAll: removeAll,
      toList: toList,
      clear: clear,
      isEmpty: sourceSet.isEmpty,
      stop: stop,
      start: start,
    );
  }

  @override
  Iterator<Cell> get iterator => _sources.iterator;
}

/// An Administrative Record providing a control interface for dynamic
/// [SynthesisCell] topographies.
///
/// [SynthesisHandle] encapsulates the operational logic required to modify
/// a convergent graph at runtime, allowing developers to add or remove
/// upstream [Cell] sources without destroying the aggregator node.
///
/// ### Example:
/// ```dart
/// final handle = SynthesisCell.handle([initialCell]);
///
/// // Dynamically add a new source
/// handle.add(networkCell);
///
/// // Temporarily pause aggregation
/// handle.stop();
///
/// // Resume later
/// handle.start();
///
/// // Access the underlying cell to observe it
/// handle.cell.observe((p) => print('Converged Pulse: ${p.payload}'));
/// ```
///
/// ### See Also:
/// * [SynthesisCell]: The node type managed by this handle.
/// * [Synapses]: The underlying mechanism used to link and unlink cells.
typedef SynthesisHandle = ({

  /// The underlying [SynthesisCell] node managed by this handle.
  SynthesisCell cell,

  /// Registers a new source cell into the synthesis aggregation.
  bool Function(Cell cell) add,

  /// De-registers a source cell and severs its topological link.
  bool Function(Cell cell) remove,

  /// Performs a batch registration of multiple source cells.
  void Function(Iterable<Cell> cells) addAll,

  /// Performs a batch de-registration of multiple source cells.
  void Function(Iterable<Cell> cells) removeAll,

  /// Returns a point-in-time snapshot of all registered source cells.
  List<Cell> Function() toList,

  /// Severs all links and empties the source cell collection.
  bool Function() clear,

  /// Indicates if the aggregator currently has zero registered sources.
  bool isEmpty,

  /// Disconnects all sources while retaining the internal membership list.
  void Function() stop,

  /// Re-establishes reactive links for all members in the current list.
  void Function() start,

});


class _OpenCell
    extends CellBase
    with OpenReceptorMixin, OpenSynapsesMixin
    implements OpenCell {

  _OpenCell({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    bool forceLock = false
  }) : super.fromNucleus(Nucleus(
    ephemeralPolicy: ephemeralPolicy,
    testRule: testRule,
    receptor: receptor,
    bind: bind,
    context: context,
    synapses: synapses,
    forceLock: forceLock
  ));

  @override
  OpenCell deputy({
    EphemeralPolicy? ephemeralPolicy,
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled
  }) {
    return (ephemeralPolicy != null || context != DeputyContext.system || testRule != TestCell.allowAll || synapses != Synapses.enabled)
        ? _OpenCellDeputy(bind: this, testRule: testRule, ephemeralPolicy: ephemeralPolicy, synapses: synapses)
        : this;
  }

  @override
  OpenCellAsync get async => OpenCellAsync(this);

  @override
  Iterable<Function> get modifiable => <Function>{
    link,       // Now defined in OpenSynapsesMixin
    emit,   // Defined in OpenReceptorMixin
    ingest, // Defined in OpenReceptorMixin
    ...super.modifiable
  };

}

/// Provides asynchronous execution of operations on a [Cell].
///
/// This wrapper enables:
/// - Thread-safe operation execution via Dart's `Future` mechanism
/// - Non-blocking cell interactions
/// - Integration with async/await patterns
///
/// ### When to use
/// You get this from `cell.async`. Use it when you need to execute commands
/// asynchronously – e.g., from UI event handlers or background tasks.
///
/// ### How it works
/// It wraps the synchronous `apply` method in a `Future`. If the cell has a
/// lock, the operation is synchronised to prevent race conditions.
///
/// ### Example Usage:
/// ```dart
/// final cell = Cell();
/// final async = cell.async;
/// final result = await async.apply((x) => x + 1, [5]);
/// ```
///
/// ## Type Parameters
/// * [C]: The specific type of [Cell] being wrapped.
class ModifiableAsync<C extends Cell> implements Async {

  /// The underlying cell instance being wrapped.
  final C _cell;

  /// Creates an asynchronous wrapper for the given [cell].
  const ModifiableAsync(C cell) : _cell = cell;

  /// Asynchronously applies a function to the wrapped cell.
  ///
  /// This method acquires a lock on the cell's properties to ensure thread safety,
  /// then delegates to the cell's synchronous [Cell.apply] method.
  ///
  /// Parameters:
  /// * [function]: The function to execute.
  /// * [positionalArguments]: Arguments passed by position.
  /// * [namedArguments]: Arguments passed by name.
  ///
  /// Returns:
  ///   A [Future] that completes with the result of the function application.
    Future apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
    }) async {

    final lock = _cell._nucleus.lock;
    return lock != null
        ? lock.synchronized(() => _cell.apply(function, positionalArguments: positionalArguments, namedArguments: namedArguments))
        : Future(() => _cell.apply(function, positionalArguments: positionalArguments, namedArguments: namedArguments));
  }

}

/// Represents the **Asynchronous Governance Interface** for an [OpenCell].
///
/// [OpenCellAsync] is a specialized executor that enables non-blocking interactions
/// with the reactive graph. It extends [ModifiableAsync] to provide type-safe
/// asynchronous overrides for the [OpenCell] surface, ensuring that high-latency
/// operations (like remote data ingestion) do not halt the **Host Environment**.
///
/// ### When to use
/// You get this from `openCell.async`. Use it when you need to inject a pulse
/// asynchronously – e.g., from an async event handler.
///
/// ### How it works
/// It wraps the synchronous `receptor` method in a `Future`. The pulse is
/// validated and processed on the event loop.
///
/// ### Non‑obvious
/// - The async version still respects the cell's [TestCell] – pulses are
///   validated just like sync calls.
/// - The `receptor` method is the only async‑specific method; `link` is
///   already `FutureOr` in the sync version.
///
/// ### Practical Scenario:
/// A `GatewayCell` receiving data from an external web-hook uses
/// `openCell.async.receptor(pulse)` to ingest the signal. This allows the
/// gateway to handle thousands of concurrent requests without blocking the
/// core **Collection**'s internal logic.
class OpenCellAsync extends ModifiableAsync<OpenCell> {

  /// Creates an asynchronous executor for an [OpenCell].
  const OpenCellAsync(super.cell) : super();

  /// Asynchronously processes an incoming [Pulse] through the cell's
  /// transformation logic.
  ///
  /// This method acts as the non-blocking entry point for **Pulse Ingestion**.
  ///
  /// ### Execution Flow:
  /// 1.  **Async Authorization**: Validates the pulse against the cell's
  ///     [TestCell] (**Integrity Gate**) on the Dart event loop.
  /// 2.  **Transformation**: If authorized, processes the signal via the
  ///     cell's [Receptor] logic.
  /// 3.  **Reactive Propagation**: Broadcasts the resulting output to all
  ///     downstream observers within the current async context.
  ///
  /// - [pulse]: The input pulse representing the external stimulus.
  ///
  /// Returns a [Future] that resolves once the transformation and
  /// initial propagation are complete.
  Future<bool> emit(Pulse pulse) async {
    bool emit(Pulse pulse) => _cell._nucleus.receptor.call(pulse) != null;
    final lock = _cell._nucleus.lock;
    if (lock != null) {
      return lock.synchronized(() => emit(pulse)).then((value) => value);
    }
    return Future<bool>(() => emit(pulse)).then((value) => value);
  }

  Future<void> ingest(Pulse pulse, {bool serializedCompletion = false}) async {
    final receptor = _cell._nucleus.receptor;
    return await receptor.async.call(pulse as PulseBase, serializedCompletion: serializedCompletion);
  }

}

/// A mixin that implements the **Manual Control Interface** for the reactive network.
///
/// This mixin provides the concrete implementation for manual data entry,
/// establishing a control plane that allows you to push data directly into a
/// cell. It ensures that every manually injected signal is processed,
/// validated, and transformed according to the cell's internal logic.
///
/// ### When to use
/// This mixin is used by cells that allow manual input (like those created via
/// [Cell.open]). It provides the standard [emit] and [ingest] methods used to
/// bridge external systems or user actions into the reactive graph.
///
/// ### How it works
/// 1. **Validation**: Every incoming pulse is first checked against the
///    cell's safety rules to ensure it is authorized.
/// 2. **Processing**: If the pulse is authorized, it is passed through the
///    cell's transformation logic to produce a resulting value.
/// 3. **Broadcast**: If the transformation is successful, the resulting
///    data is broadcast to all connected parts of the network.
///
/// ### Non‑obvious
/// - **Async Support**: If the cell's safety check involves external
///   validation (like a database or network check), the [emit] method
///   automatically returns a `Future`.
/// - **Error Handling**: If an error occurs during processing, the mixin
///   catches it and cancels the update to prevent the failure from crashing
///   the reactive network.
/// - **Signal Termination**: If a pulse fails validation or the transformation
///   logic returns no value, the update is dropped and nothing is broadcast.
mixin OpenReceptorMixin on Cell {

  /// Processes and broadcasts an incoming [Pulse] through the cell's
  /// transformation logic.
  ///
  /// [emit]] acts as the primary **Manual Ingress Point**. It allows external
  /// code to inject data pulses directly into the cell. If the pulse is accepted,
  /// it is transformed by the internal logic and propagated to all connected
  /// observers.
  ///
  /// ### How it works
  /// 1. **Authorization**: The pulse is first sent to the **Integrity Gate**
  ///    (the cell's [testRule]).
  /// 2. **Transformation**: If authorized, the pulse is passed to the
  ///    internal [Receptor] logic.
  /// 3. **Propagation**: The resulting pulse (if any) is then broadcast
  ///    downstream to the rest of the network.
  ///
  /// ### Non‑obvious
  /// - **Async Support**: If the cell's safety check ([testRule]) is
  ///   asynchronous, this method returns a [Future].
  /// - **Signal Termination**: If the safety check fails, or if the
  ///   transformation logic returns `null`, the signal is terminated
  ///   and no data is broadcast.
  /// - **Error Handling**: Any errors thrown during the transformation
  ///   step are caught, and the emission is treated as a silent failure
  ///   (returns `null`).
  ///
  /// ### Parameters:
  /// * [pulse]: The data pulse to be injected into the network.
  ///
  /// ### Returns:
  /// A [FutureOr] containing the resulting [Pulse] if the emission was
  /// successful and accepted, or `null` if the pulse was rejected or
  /// suppressed.
  FutureOr<Pulse?> emit(Pulse pulse) {
    final validation = validate(pulse, host: this);

    // Helper to execute the core receptor logic
    FutureOr<Pulse?> process() {
      try {
        return _nucleus.receptor.call(pulse);
      } catch (_) {
        return null;
      }
    }

    // 1. Branch: Asynchronous Path (Remote Governance/IO)
    if (validation is Future<bool>) {
      return validation.then((passed) => passed ? process() : null);
    }

    // 2. Branch: Synchronous Path (Native Speed)
    return validation ? process() : null;
  }

  /// Synthesizes an **Awaitable Signal Injection**—a specialized entry point
  /// that waits for the entire reactive network to finish processing a change.
  ///
  /// The [ingest] acts as a **Guaranteed Completion Port**. Unlike [emit],
  /// which returns as soon as the signal enters the network, [ingest] returns
  /// a [Future] that only resolves once every downstream cell, effect, and
  /// observer has finished their work.
  ///
  /// ### When to use
  /// Use this when your code needs to be absolutely sure that the application
  /// has fully reacted to a signal before moving to the next step.
  ///
  /// - **Integration Testing**: Waiting for the app state to fully settle
  ///   before running expectations or assertions.
  /// - **Sequential Workflows**: Pushing a "Save" command and waiting for
  ///   all background synchronization effects to finish.
  /// - **Critical Transitions**: Ensuring that a UI "Loading" state only
  ///   clears after all downstream data transformations are complete.
  ///
  /// ### How it works
  /// 1. The pulse is injected into the cell's transformation logic.
  /// 2. The framework tracks the "causal tree"—every downstream change
  ///    triggered by this specific pulse.
  /// 3. The returned [Future] stays active while pulses are still moving
  ///    through the fabric.
  /// 4. Once all related side effects are done, the [Future] completes.
  ///
  /// ### Non‑obvious
  /// - **Full Propagation**: This doesn't just wait for the immediate cell;
  ///   it waits for the *entire* ripple effect across the network.
  /// - **Serialization**: If [serializedCompletion] is set to `true`, the
  ///   network ensures this pulse is processed in a strict queue, preventing
  ///   it from overlapping with other incoming signals.
  /// - **Error Handling**: If a downstream effect fails, the [Future] will
  ///   still complete once the failure is handled, ensuring your code
  ///   doesn't hang indefinitely.
  ///
  /// ### Example: Atomic Setup
  /// ```dart
  /// // Inject a setup signal and wait for all modules to initialize
  /// await systemGate.ingest(Pulse('INIT_ALL'), serializedCompletion: true);
  ///
  /// // Now we are guaranteed that every observer has finished its setup
  /// proceedToHomePage();
  /// ```
  ///
  /// ### Parameters:
  /// * [pulse]: **The Stimulus.** The data to be injected into the network.
  /// * [serializedCompletion]: **Order Enforcement.** If `true`, ensures
  ///   this signal is processed and finished in the exact order it arrived.
  ///
  /// ### Returns:
  /// A [Future] that resolves once the entire downstream reactive chain
  /// is settled.
  ///
  /// ### See Also:
  /// * [emit]: For a "fire-and-forget" manual injection.
  /// * [Cell.open]: The factory used to create cells that support this method.
  Future<void> ingest(Pulse pulse, {bool serializedCompletion = false}) async {
    final receptor = _nucleus.receptor;
    return await receptor.async.call(pulse as PulseBase, serializedCompletion: serializedCompletion);
  }

}

/// A mixin that implements the **Reactive Topology Interface** for [OpenCell] architectures.
///
/// This mixin provides the concrete implementation for the [link] method,
/// establishing the primary mechanism for **Downstream Propagation**. It serves as
/// the framework's **Connectivity Layer**, allowing external entities or agents to
/// dynamically wire the reactive graph while ensuring all connections are
/// authorized by the node's governance guardrails.
///
/// ### When to use
/// This is used internally by `_OpenCell`. You don't use it directly.
///
/// ### How it works
/// It implements `link` by:
/// 1. Delegating to the cell's [Synapses] to add the downstream cell.
/// 2. Returning an unlinker closure (or `null` if rejected).
///
/// ### Non‑obvious
/// - The link is governed by the cell's [TestCell] – it can be rejected.
/// - The unlinker removes the link when called.
/// - If the validation is asynchronous, the method returns a `Future`.
mixin OpenSynapsesMixin on Cell {

  /// Establishes a governed reactive connection between this cell and a
  /// downstream [cell].
  ///
  /// This method is the primary tool for **Graph Expansion**. It verifies
  /// the link request against the cell's **Integrity Gate** before
  /// permitting the signal flow.
  ///
  /// ### Parameters:
  /// - [cell]: The downstream [Cell] instance that will observe and react
  ///   to pulses emitted by this node.
  ///
  /// ### Returns:
  /// A [FutureOr] containing a closure (`void Function()`) to undo the link,
  /// or `null` if the connection was rejected by governance.
  FutureOr<void Function()?> link(Cell cell) {
    // 1. Capture the FutureOr result from the internal synapse gate
    final result = _nucleus.synapses.link(this, downstreamCell: cell);

    // 2. Define the unlinker (cancellation closure)
    void unlinker() => _nucleus.synapses.unlink(this, downstreamCell: cell);

    // 3. Branch: Asynchronous Path (Remote Authorization)
    if (result is Future<bool>) {
      return result.then((passed) => passed ? unlinker : null);
    }

    // 4. Branch: Synchronous Path (Native Speed)
    return result ? unlinker : null;
  }
}

