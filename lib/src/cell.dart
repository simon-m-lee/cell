// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell.dart';

/// A reactive node: holds state (or relays signals), validates every
/// incoming change against a policy, and broadcasts accepted changes to
/// whatever else is listening.
///
/// Internally, a [Cell]'s behavior is split into four independent,
/// swappable pieces — a [Receptor] (how it transforms an incoming
/// [Pulse]), a [TestCell] (what it's allowed to accept), a [Context] (what
/// tier/domain it belongs to), and [Synapses] (who it notifies on change).
/// You don't construct any of these directly for ordinary use — they all
/// have working defaults, and the static operators below hide them
/// entirely.
///
/// ### Where to start
/// **First 16 operators**: Almost everything is built from one of these. They will
/// cover most of your daily reactive programming needs. They're ordered from
/// most essential to more advanced.
///
/// These are ordered for a learning path:
///   get data in →
///   hold state →
///   react in the UI →
///   shape streams →
///   go async →
///   combine sources.
///
/// * [Cell.ingress] — How intent/events enter the graph
/// * [Cell.state] — Retained app state you read and update
/// * [Cell.observe] — Side effects: UI, logging, wiring widgets
/// * [Cell.derive] — Pure view-models / projections from state
/// * [Cell.hub] — Routing signals to specific handlers
/// * [Cell.open] — Module boundaries for manual control
/// * [Cell.distinct] — Skip redundant updates and rebuilds
/// * [Cell.valve] — Flow control: only allow pulses when a condition is met
/// * [Cell.throttle]/[Cell.debounce] — Timing control: input rate-limiting
/// * [Cell.asyncMap] — HTTP/DB work (latestOnly / exhaust)
/// * [Cell.fromFuture]/[Cell.fromStream] — Bridge Futures and Streams into Cell
/// * [Cell.synthesis] — merge multiple sources into one consensus
/// * [Cell.sanitized] — Data sanitization / validation
/// * [Cell.switchMap] - Selected user / tab / locale → active upstream
/// * [Cell.transaction] — Multi-cell atomic updates (money, stock, forms)
/// * [Cell.txApply] —  batch multiple apply() into a single commit.
///
/// Each works with zero knowledge of [Receptor], [TestCell], [Context], or
/// [Synapses] — all optional, all defaulted. They represent the
/// **Standard Entry Point**, allowing you to build complex reactive systems
/// by connecting simple building blocks. While you focus on your logic, the
/// framework automatically manages the input (Ingress), logic (Transformation),
/// and notifications (Egress), handling all security checks and verification
/// steps in the background.
///
/// ### Identity
/// A cell obtained via [deputy] or [unmodifiable] is a *proxy*, not a
/// copy — it shares its principal's underlying state. `cell ==
/// cell.deputy()` is `true`; they're interchangeable in [Set]s and [Map]s.
/// What differs is what each is *permitted* to do ([validate]), never what
/// data it holds.
///
/// ### Going further
/// [Cell.governed] and [Cell.fromNucleus] expose full control over
/// lifecycle, security tier, and concurrency. Reach for these only when
/// the operators above are genuinely insufficient — e.g. building
/// infrastructure nodes, not typical application state.
///
/// For a rich ecosystem of reactive primitives, see **cell_flow**—a
/// complementary library providing over 60+ specialized operators
/// for complex stream orchestration, advanced filtering, and
/// high-level data synchronization.
///
/// ### See Also:
/// - [Pulse] (the signal a cell processes).
/// - [ValueCell] (the concrete stateful type returned by [Cell.state]).
/// - **HowTo**: See `guide/HowTo_Start.md` for a comprehensive guide on
///   getting started with the Cell architecture and reactive patterns.
/// {@category Getting Started}
/// {@category Core}
/// {@category Core 16 Operators}
abstract interface class Cell {

  /// Internal evolve of the cell, encapsulating its configuration.
  /// This typically includes its [Receptor], [TestCell], [Synapses], and
  /// any bound cell. Access is protected (internal to the library).
  Nucleus get _nucleus;

  /// Creates a standard, stateful [Cell] instance—the foundational execution
  /// node of the reactive network.
  ///
  /// This factory is the primary **Human-Centric** entry point for the framework.
  /// It assembles the cell's **Architectural Nucleus** with sensible defaults,
  /// allowing developers to focus on business logic without the overhead of
  /// explicit governance configuration.
  ///
  /// ### When to use
  /// Use this when you need a basic reactive node that processes pulses
  /// without persistent state. Most applications will use [Cell.state] or
  /// [Cell.ingress] instead; this constructor is a fallback for custom
  /// relays or stateless processors.
  ///
  /// ### How it works
  /// - [bind]: Links to an upstream cell – this cell will automatically
  ///   receive pulses from it.
  /// - [receptor]: Defines how incoming pulses are transformed.
  ///   Defaults to [Receptor.passThrough] (no transformation).
  /// - [testRule]: Validation gate for incoming pulses.
  ///   Defaults to [TestCell.allowAll] (no restrictions).
  /// - [synapses]: Controls who receives this cell's outgoing pulses.
  ///   Defaults to [Synapses.enabled] (broadcasts to all observers).
  ///
  /// ### Non‑obvious
  /// The [receptor] and [testRule] are shared across deputies unless
  /// overridden. If you need different behavior for a restricted view,
  /// use [deputy] instead of creating a separate cell.
  ///
  /// ### Example: Reactive Counter
  /// ```dart
  /// final counter = Cell(
  ///   receptor: Receptor((cell, pulse, {user}) {
  ///     final current = cell.state as int? ?? 0;
  ///     return Pulse(current + 1);
  ///   }),
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [bind]: Optional upstream [Cell]. Establishes the primary **Ingress
  ///   Link** for automated signal flow.
  /// - [receptor]: The **Transformation Pipeline** defining how the cell
  ///   synthesizes incoming [Pulse] data. Defaults to [Receptor.passThrough].
  /// - [testRule]: The **Integrity Gate** validator used to authorize and
  ///   sanitize state changes. Defaults to [TestCell.allowAll].
  /// - [synapses]: Configuration for the **Signal Distribution Network**
  ///   (Egress). Defaults to [Synapses.enabled].
  ///
  /// ### Returns:
  /// A live [Cell] instance integrated into the reactive ecosystem,
  /// ready to observe, transform, and broadcast signals.
  ///
  /// See also:
  /// * [Cell.governed]: For explicit governance, lifecycle policies, and
  ///   atomic isolation.
  /// * [Cell.deputy]: For creating capability-gated proxies of existing cells.
  factory Cell({
    Cell? bind,
    Receptor receptor,
    TestCell testRule,
    Synapses synapses,
  }) = _Cell;

  /// Synthesizes a fully managed [Cell] instance with explicit control over
  /// its **Identity Lifecycle**, **Administrative Policy**, and
  /// **Atomic Isolation**.
  ///
  /// This factory serves as the primary **Administrative Enforcement Point**
  /// for nodes requiring strict security and compliance. It allows for the
  /// creation of a dedicated security perimeter, ensuring that every state
  /// transition is validated against a formal **Capability-Based Access
  /// Control (CBAC)** manifest.
  ///
  /// ### When to use
  /// Only when you need fine‑grained governance: TTL, specific authority
  /// tiers, or atomic locking. For typical application state, prefer the
  /// simpler [Cell.state] or [Cell.ingress].
  ///
  /// ### How it works
  /// All parameters are mandatory (no defaults). You must explicitly
  /// supply a [context] – there is no system fallback. This ensures every
  /// governed node has a defined security posture.
  ///
  /// ### Non‑obvious
  /// Governed cells participate in a mutual authorization handshake:
  /// both the pulse and the receptor scrutinise each other's context
  /// before data is exchanged. If either side fails the check, the pulse
  /// is neutralised.
  ///
  /// ### Parameters:
  /// * [ephemeralPolicy]: **Resource Management.** Defines the TTL or
  ///   invalidation triggers for the node.
  /// * [bind]: **Ingress Link.** The primary dependency for reactive flow.
  /// * [context]: **Administrative Context.** The metadata registry
  ///   defining Authority Tier, Clearance, and Sensitivity.
  /// * [receptor]: **Transformation Pipeline.** The logic defining how the
  ///   cell synthesizes incoming stimuli.
  /// * [testRule]: **Integrity Gate.** The [TestCell] used to authorize
  ///   state changes. Defaults to [TestCell.allowAll].
  /// * [synapses]: **Egress Network.** Configures signal routing and
  ///   distribution behavior.
  /// * [forceLock]: **Atomic Isolation.** If true, establishes a dedicated
  ///   synchronization domain for the node.
  ///
  /// ### Returns:
  /// A fully managed [Cell] instance with a dedicated policy perimeter and
  /// explicit lifecycle configuration.
  factory Cell.governed({
    EphemeralPolicy? ephemeralPolicy,
    Context context,

    Cell? bind,
    Receptor receptor,
    TestCell testRule,
    Synapses synapses,

    bool forceLock
  }) = _Cell;

  /// Activates a live [Cell] instance from a pre-configured [Nucleus] blueprint.
  ///
  /// This factory serves as the primary **Node Hydration Engine** for the
  /// framework. It allows for the direct instantiation of a reactive node
  /// from an existing property record, providing precise architectural control
  /// over the node's behavioral logic, synchronization domain, and structural
  /// identity.
  ///
  /// ### When to use
  /// Use this when you need to reconstruct a cell from a persisted or
  /// serialized nucleus, clone an existing cell's behavior with a fresh
  /// state, or when you are building framework-level infrastructure that
  /// requires explicit control over the activation process. Most application
  /// code should use the simpler [Cell] factory.
  ///
  /// ### How it works
  /// The factory takes a pre-configured [Nucleus] and activates it by
  /// binding it to a new live cell instance. If the nucleus is already
  /// activated (bound to another cell), it is automatically cloned to
  /// prevent state sharing conflicts. The resulting cell inherits all
  /// properties from the nucleus: [Receptor] logic, [TestCell] rules,
  /// [Context], [Synapses] configuration, and synchronization [Lock].
  ///
  /// ### The Proxy Pattern & Inheritance
  /// This factory is the underlying mechanism for the **Proxy Pattern**.
  /// When a [Nucleus] is extended via [Nucleus.evolve], this factory
  /// "activates" that extension into a live proxy:
  /// - The resulting cell shares the **Physical Data Source** (and
  ///   potentially the [Lock]) of its principal but operates under the
  ///   specific [Context] and [TestCell] rules defined in the provided
  ///   nucleus.
  /// - This allows for the creation of multiple specialized "Views" of
  ///   the same underlying data source, each with different permissions
  ///   or execution priorities.
  ///
  /// ### Synchronization & Atomic Integrity
  /// The resulting instance inherits the optional synchronization domain
  /// (the [Lock]) defined within the nucleus. If a lock is provided, it
  /// ensures that the cell enters the **Directed Acyclic Graph (DAG)**
  /// as a thread-safe, atomically consistent node. This mechanism
  /// allows developers to group multiple cells into a single
  /// **Atomic Transaction Domain** by sharing a common lock.
  ///
  /// ### Non‑obvious
  /// - If the provided nucleus is already activated, it is **automatically
  ///   cloned** to prevent state sharing conflicts between cells.
  /// - After hydration, the cell automatically links to any [bind] cell
  ///   specified in the nucleus, establishing its position in the reactive
  ///   graph. If linking fails, the cell still initialises to maintain
  ///   graph availability.
  /// - The nucleus's [Synapses] configuration is inherited as-is; if
  ///   `Synapses.enabled` is set, a fresh registry is created per cell.
  /// - The [Lock] is inherited from the nucleus; if the nucleus uses a
  ///   shared lock, multiple cells can operate in the same atomic domain.
  ///
  /// ### Example: Hydrating from a Pre-configured Nucleus
  /// ```dart
  /// // Define a reusable nucleus blueprint.
  /// final authNucleus = Nucleus(
  ///   context: Context.module('Auth'),
  ///   receptor: Receptor((cell, pulse, {user}) {
  ///     final token = pulse.payload as String;
  ///     return Pulse(token.isNotEmpty ? 'Valid' : 'Invalid');
  ///   }),
  ///   testRule: TestCell((value, {host, ...}) => value is String),
  /// );
  ///
  /// // Activate multiple cells from the same blueprint.
  /// final authCell1 = Cell.fromNucleus(authNucleus);
  /// final authCell2 = Cell.fromNucleus(authNucleus.clone);
  /// ```
  ///
  /// ### Parameters:
  /// - [nucleus]: **Required.** The [Nucleus] instance that serves as the
  ///   **Static Blueprint** for the cell. This defines the node's [Receptor]
  ///   logic, [TestCell] rules, [Context], [Synapses] configuration, and
  ///   optional synchronization [Lock].
  ///
  /// ### Returns:
  /// A fully hydrated [Cell] instance that is integrated into the reactive
  /// ecosystem, ready to process pulses and notify observers.
  ///
  /// See also:
  /// * [Nucleus] – The immutable blueprint that defines cell behavior.
  /// * [Nucleus.clone] – For creating a detached copy of a nucleus.
  /// * [Nucleus.evolve] – For extending a nucleus with localized overrides.
  /// * [Cell.deputy] – For creating restricted views of a cell.
  /// * [Cell.governed] – For explicit governance configuration.
  /// * [Cell.fromNucleus] – The entry point for this factory.
  factory Cell.fromNucleus(Nucleus nucleus)
  = _Cell.fromNucleus;

  /// Synthesizes a **Stateless Event Gateway**—the primary entry point for
  /// bridging imperative signals into the reactive graph.
  ///
  /// The `ingress` factory creates a **Terminal Input Node**. Unlike state
  /// cells, an ingress node has no memory and does not persist values. It
  /// functions strictly as a relay, transforming raw external stimuli into
  /// reactive [Pulse]s for immediate downstream broadcast.
  ///
  /// ### When to use
  /// - **Imperative Integration**: Bridging UI interactions (taps, swipes),
  ///   system events (lifecycle changes), or hardware interrupts into the
  ///   reactive fabric.
  /// - **Stateless Triggers**: When you need to initiate a reaction chain
  ///   (e.g., "Reset App", "Logout") without needing to track a persistent
  ///   state value.
  /// - **Data Normalization**: Using the `refine` parameter to validate or
  ///   sanitize raw inputs before they reach the rest of the application.
  ///
  /// ### How it works
  /// 1. **Capture**: The `emit` or `emitAsync` handles receive raw data of type `I`.
  /// 2. **Packaging**: The handle wraps the data into a [Pulse], attaching
  ///    metadata like the source [Context] and timestamp.
  /// 3. **Refinement**: If provided, the `refine` function is called to
  ///    transform or filter the pulse. If it returns `null`, the signal is
  ///    silently dropped.
  /// 4. **Broadcast**: The resulting pulse is handed to the cell's [Synapses]
  ///    to be distributed to all linked downstream observers.
  ///
  /// ### Design Note: Statelessness vs. Persistence
  /// - **[Cell.ingress]** is a **Flow Primitive**. It is designed for
  ///   ephemeral events. It does not store data, and its `cell` cannot be
  ///   read for a "current" value.
  /// - **[Cell.state]** is a **Storage Primitive**. It is designed for
  ///   persistent data that evolves over time and can be read at any time.
  ///
  /// ### Non‑obvious
  /// - **No State Storage**: An ingress cell is a "pass-through" node. It
  ///   consumes zero storage memory for values.
  /// - **Pulse Transparency**: Pulses passing through an ingress node
  ///   preserve their forensic history, allowing downstream nodes to
  ///   trace events back to the original imperative trigger.
  /// - **Graph Stabilization**: The `ingest` handle with
  ///   `serializedCompletion: true` allows your imperative code to `await`
  ///   the completion of the entire reactive cascade triggered by the event.
  /// - **Integrity Gate**: All inputs must pass the [testRule] and
  ///   [context] authorization checks before being broadcast.
  ///
  /// ### Example: Clean, transformed ingress
  /// ```dart
  /// final IngressHandle<String> searchGate = Cell.ingress<String>(
  ///   refine: (Cell host, Pulse<String> input) {
  ///     final raw = (input.payload ?? '').toString().trim();
  ///     if (raw.isEmpty) return null; // suppress empty queries
  ///
  ///     // return a new Pulse with the cleaned value.
  ///     return Pulse<String>(raw.toLowerCase(), type: 'search.query');
  ///   },
  /// );
  ///
  /// final observer = Cell.observe(
  ///   source: searchGate.cell,
  ///   effect: (Pulse pulse) {
  ///     print('  → observer received: "${pulse.payload}"');
  ///   },
  /// );
  ///
  /// searchGate.emit('  Hello World  '); // Prints: observer received: "hello world"
  /// ```
  /// 
  /// ### Parameters:
  /// * [refine]: **Optional.** The **Pre-Transformation Hook**. A function
  ///   used to normalize raw inputs or reject them (`return null`) before
  ///   they enter the network.
  /// * [ephemeralPolicy]: **Lifecycle Management.** Defines how the gateway
  ///   is cleaned up when it has no more downstream listeners.
  /// * [source]: **Ingress Source.** An optional upstream cell to observe
  ///   automatically, turning this node into a reactive relay.
  /// * [context]: **Operational Authority.** The security and priority tier
  ///   governing events entering through this gateway.
  /// * [receptor]: **Transformation Engine.** The underlying logic for
  ///   pulse processing.
  /// * [testRule]: **Integrity Gate.** A safety check that must approve
  ///   every incoming stimulus.
  /// * [synapses]: **Egress Network.** Configures how signals are
  ///   distributed to the rest of the application.
  /// * [forceLock]: **Atomic Isolation.** If `true`, ensures that
  ///   concurrent inputs are processed sequentially via a dedicated lock.
  ///
  /// ### Returns:
  /// An [IngressHandle] (Record) providing:
  /// * `cell`: The stateless [Cell] instance representing this gateway.
  /// * `emit`: A synchronous method for manual event injection.
  /// * `emitAsync`: An asynchronous, lock-protected version of `emit`.
  /// * `ingest`: A high-level handle for complex signal orchestration.
  ///
  /// ### See Also:
  /// - [Cell.state]: The standard factory for persistent state.
  /// - [Cell.open]: For manual connection and observer management.
  /// - **Example**: See `example/ingress_demo.dart` for a complete executable
  ///   walkthrough of utilizing [IngressHandle] for manual event injection.
  /// - **HowTo**: See `guide/HowTo_Start.md` for a guide on bridging
  ///   imperative and reactive code.
  /// {@category Core 16 Operators}
  static IngressHandle<I> ingress<I>({
    Pulse<I?>? Function(Cell host, Pulse<I> input)? refine,
    EphemeralPolicy? ephemeralPolicy,
    Cell? source,
    Context context = Context.system,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    bool forceLock = false,
  }) =>
      _ingress(
        refine: refine,
        bind: source,
        context: context,
        receptor: receptor,
        testRule: testRule,
        synapses: synapses,
        forceLock: forceLock,
      );

  /// Synthesizes a **Stateful Micro-Service**—the primary primitive for
  /// reactive state management.
  ///
  /// A `state` cell acts as a persistent **Single Source of Truth** that
  /// combines storage, transformation logic, and broadcast distribution.
  ///
  /// ### When to use
  /// - **Application State**: Managing variables like `isLoggedIn`,
  ///   `userProfile`, or `shoppingCart`.
  /// - **Event Transformation**: Converting raw inputs (like button clicks)
  ///   into structured state changes (like incrementing a counter).
  /// - **Data Orchestration**: Bridging multiple sources into a unified
  ///   observable node using the [bind] parameter.
  ///
  /// ### How it works
  /// 1. **Storage**: The cell allocates a private `Box` to persist the
  ///    current value of type [V].
  /// 2. **Ingress**: It accepts pulses from manual `update()` calls or
  ///    upstream [bind] dependencies.
  /// 3. **Evolution**: If an [evolve] function is provided, it is invoked
  ///    synchronously for every incoming pulse. It compares the
  ///    `host.value` (current state) with the `input` pulse to decide
  ///    the next state.
  /// 4. **Commitment**: If `evolve` returns a new [Pulse], the state is
  ///    updated and immediately broadcast via [Synapses].
  ///
  /// ### Non‑obvious
  /// - **Initial Seed**: The [initial] value is written directly to storage,
  ///   bypassing the transformation cycle.
  /// - **Null Filtering**: If [evolve] returns `null`, the update is
  ///   rejected, the storage remains unchanged, and no propagation occurs.
  /// - **Atomic Isolation**: By default, state updates are serialized
  ///   through an internal [Lock] to prevent race conditions during
  ///   concurrent async operations.
  ///
  /// ### Example: Counter
  /// ```dart
  /// final counter = Cell.state(0, (host, input) {
  ///   final delta = input.payload as int;
  ///   return Pulse(host.value + delta);
  /// });
  ///
  /// counter.update(5); // value becomes 5
  /// ```
  ///
  /// ### Parameters:
  /// * [initial]: The **Initial Seed.** The value assigned to the cell at
  ///   creation.
  /// * [evolve]: **Optional.** The **Transformation Pipeline** logic. It
  ///   determines how the incoming `input` maps to the final committed
  ///   state based on the current `host.value`.
  ///
  /// ### Returns:
  /// A [StateHandle] (Record) providing:
  /// * `cell`: The persistent, stateful [ValueCell] instance.
  /// * `update`: A synchronous gateway for manual state updates.
  /// * `updateAsync`: An asynchronous, lock-protected version of `update`.
  /// * `ingest`: A high-level ingress handle for signal orchestration.
  ///
  /// ### See Also:
  /// - [Cell.ingress]: For stateless gateways and transient event sources.
  /// - **HowTo**: See `guide/HowTo_Start.md` for a comprehensive guide on
  ///   state management and reactive patterns.
  /// {@category Core 16 Operators}
  static StateHandle<V> state<V>({
    V? initial,
    Pulse<V>? Function(ValueCell<V> host, Pulse input)? evolve,
  }) {
    return ValueCell.create<V>(
      ValueNucleus<V>(
        transform:
            evolve != null
                ? (host, input, {user}) => evolve(host, input)
                : null,
      ),
      value: initial,
    );
  }

  /// Synthesizes an **Output Terminal** designed to observe the reactive graph
  /// and emit imperative side effects.
  ///
  /// The [observe] factory creates a point of **Signal Termination**—the boundary
  /// where reactive [Pulse]s exit the automated graph and are converted into
  /// real-world actions (e.g., UI updates, disk persistence, or hardware commands).
  ///
  /// ### When to use
  /// Use this when you need to react to a cell's changes with side effects:
  /// updating UI, writing to a database, sending a network request, or logging.
  ///
  /// - **UI Binding**: Updating views or controllers in response to state changes.
  /// - **Persistence**: Saving the results of a transformation chain to storage.
  /// - **External Integration**: Triggering third-party APIs or hardware signals.
  ///
  /// ### How it works
  /// 1. The observer establishes a persistent link to the [source] source.
  /// 2. Every pulse emitted by the source is passed through the [testRule].
  /// 3. If the stimulus is valid, the [effect] callback is executed.
  /// 4. The returned [EgressHandle] allows you to `start` or `stop` the observer
  ///    manually, providing complete lifecycle control.
  ///
  /// ### Non‑obvious
  /// - **Terminal Nature**: This node is a "sink"—it has no downstream
  ///   observers and never propagates pulses further, effectively preventing
  ///   causal loops.
  /// - **Dormancy**: Observers can be created in a dormant state if
  ///   [initiallyStarted] is `false`, meaning they will ignore pulses until
  ///   `.start()` is called on the handle.
  ///
  /// ### Example: UI Update Observer
  /// ```dart
  /// final counter = Cell.state<int>(initial: 0);
  /// final uiUpdate = Cell.observe<int>(
  ///   source: counter.cell,
  ///   effect: (pulse) {
  ///     // Execute the side-effect (Egress)
  ///     setState(() => count = pulse.payload);
  ///   },
  /// );
  ///
  /// uiUpdate.start();
  /// ```
  ///
  /// ### Parameters:
  /// * [source]: **The Ingress Source.** The [Cell] instance to observe.
  /// * [effect]: **The Egress Logic.** An imperative callback executed
  ///   when a valid stimulus is received. This function is the terminal
  ///   point for side effects and focuses purely on the [Pulse].
  /// * [initiallyStarted]: **Initial Lifecycle State.** If `true`, the
  ///   observer begins processing signals immediately upon creation.
  ///
  /// ### Returns:
  /// An [EgressHandle] (Record) providing:
  /// * `cell`: The live observer node.
  /// * `start`: A closure to enable side-effect processing.
  /// * `stop`: A closure to disable side-effect processing.
  ///
  /// ### See Also:
  /// * [EgressHandle]: For controlling the lifecycle (start/stop) of the observer.
  /// - **Example**: See `example/observe_demo.dart` for a complete executable
  ///   walkthrough of UI side-effects, terminal lifecycle management, and forensic logging.
  /// {@category Core 16 Operators}
  static EgressHandle<P> observe<P extends Pulse>({
    required Cell source,
    required void Function(P pulse) effect,
    bool initiallyStarted = true,
  }) =>
      _observe(
        bind: source,
        effect: effect,
        initiallyStarted: initiallyStarted,
      );

  /// Synthesizes a **Functional Projection**—a specialized node that
  /// performs a pure, deterministic transformation on an upstream source.
  ///
  /// The [derive] factory is the primary tool for **Data Refinement**.
  /// It creates a strictly reactive 1-to-1 mapping where every incoming
  /// pulse is projected into a new form based on the [project] logic.
  ///
  /// ### When to use
  /// Use this when you need to change the shape or type of a single data
  /// stream—for example, converting a "User" object into a "Username" string.
  ///
  /// - **Type Conversion**: Mapping a raw model to a UI-friendly view model.
  /// - **Data Sanitization**: Trimming strings or normalizing numbers.
  /// - **State Extraction**: Pulling a specific property out of a complex state.
  ///
  /// ### How it works
  /// 1. The cell establishes a persistent link to the [source] source.
  /// 2. Every pulse emitted by the source triggers the [project] function.
  /// 3. The resulting pulse is automatically wrapped as an [EvolvedPulse]
  ///    and propagated to downstream observers.
  ///
  /// ### Non‑obvious
  /// - **Causal Lineage**: Projections automatically preserve **Causal
  ///   Provenance**. The resulting pulse is an `EvolvedPulse` linked to
  ///   the original stimulus.
  /// - **Implicit Suppression**: If the [project] returns `null`, the
  ///   derivation acts as an implicit [valve] and terminates the signal.
  /// - **Statelessness**: Derivations do not store state; they compute
  ///   results on-demand. Use [Cell.state] if you need state persistence.
  /// - **Flow Control**: Use the [synapses] parameter to attach a
  ///   [PropagationPolicy]. This allows you to debounce state emissions,
  ///   throttle high-frequency updates, or batch multiple state changes
  ///   into a single downstream pulse.
  ///
  /// ### Example: Name Extraction
  /// ```dart
  /// final username = Cell.derive<UserPulse, StringPulse>(
  ///   source: userProfile.cell,
  ///   project: (pulse) => Pulse(pulse.payload.displayName),
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [source]: **The Ingress Source.** The single upstream [Cell] to observe.
  /// * [project]: **The Projection Logic.** A pure function that defines
  ///   how the input pulse maps to the output pulse.
  ///
  /// ### Returns:
  /// A [Cell] instance representing a **Functional Transformation**. It
  /// dynamically computes its state by applying the [project] logic to
  /// the upstream [source] source.
  ///
  /// ### See Also:
  /// * [Cell.synthesis]: For merging multiple sources into one consensus.
  /// * [Cell.state]: For conditional suppression without transformation.
  /// - **Example**: See `example/derive_demo.dart` for a walkthrough of
  ///   chained projections and causal tracing.
  /// {@category Core 16 Operators}
  static Cell derive<I extends Pulse, O extends Pulse>({
    required Cell source,
    required O Function(I input) project,
  }) {
    final receptor = _Receptor(reaction: (pulse, cell, {user}) => project(pulse as I));
    return Cell(bind: source);
  }

  /// Synthesizes a **Multi-Destination Router**—a specialized node that acts as
  /// a reactive demultiplexer, directing signals to specialized handlers.
  ///
  /// The [hub] factory is the primary tool for **Signal Orchestration**. It allows
  /// a single ingress point to govern a network of [spokes], routing pulses based
  /// on their categorical [Pulse.type] or forensic metadata.
  ///
  /// ### When to use
  /// Use this when you have a centralized event stream (like a WebSocket or
  /// global message bus) that needs to be distributed to specific modules
  /// based on the type of message received.
  ///
  /// - **Pattern Matching**: Routing signals like `user.auth.*` to an auth spoke.
  /// - **Multicasting**: Delivering the same telemetry pulse to both a logger
  ///   and a real-time dashboard.
  /// - **Fallback Handling**: Providing a safety-net spoke for unrecognized signals.
  /// - **Priority Routing**: Ensuring high-priority system commands are
  ///   processed before general telemetry.
  ///
  /// ### How it works
  /// 1. A pulse is injected via the `emit` gateway (The **Ingress Port**).
  /// 2. The hub evaluates the [Pulse.type] against its registered [spokes]
  ///    using the chosen [HubRouting] strategy.
  /// 3. Matching spokes are sorted by their defined priority.
  /// 4. The signal is dispatched either to the highest-priority match (Standard)
  ///    or all matches (Multicast).
  ///
  /// ### Non‑obvious
  /// - **Longest-Match Wins**: In [HubRouting.prefix] mode, the router
  ///   automatically selects the spoke with the most specific key.
  /// - **CBAC Enforcement**: [governedSpokes] allow you to restrict specific
  ///   routes to callers holding a required [DeputyContext] mandate.
  /// - **Audit Trail**: The hub maintains the **Causal Provenance** of routed
  ///   signals, allowing you to trace a spoke's execution back to the
  ///   original hub injection.
  ///
  /// ### Example – fallback + priority
  /// ```dart
  /// final hub = Cell.hub(
  ///   registrations: [
  ///     (key: 'user.login', priority: 10, handler: handleLogin, …),
  ///     (key: 'user.*',     priority: 5,  handler: handleUser,  …),
  ///     (key: 'audit',      priority: 0,  handler: handleAudit, …),
  ///   ],
  ///   fallback: 'audit',
  ///   routing: HubRouting.pattern,
  /// );
  /// ```
  ///
  /// ### Example: Priority Routing
  /// ```dart
  /// final appHub = Cell.hub(
  ///   registrations: [
  ///     (key: 'sys.critical', priority: 0,  handler: shutdownHandler),
  ///     (key: 'sys.*',        priority: 10, handler: logHandler),
  ///   ],
  ///   routing: HubRouting.pattern,
  ///   fallback: 'sys.log',
  /// );
  /// ```
  ///
  /// ### Example – multicast
  /// ```dart
  /// final hub = Cell.hub(
  ///   spokes: {
  ///     'metrics': recordMetric,
  ///     'log':     writeLog,
  ///   },
  ///   routing: HubRouting.multicast,   // or multicast: true
  /// );
  /// // Every pulse is delivered to both spokes.
  /// ```
  ///
  /// ### Parameters:
  /// * [spokes]: **Direct Routing Map.** A map of exact-match keys to reactive
  ///   transformation handlers.
  /// * [governedSpokes]: **Authority-Based Routing.** Maps [DeputyContext]
  ///   mandates to specific receptors for secure signal handling.
  /// * [registrations]: **Ordered Routing Registry.** A list of
  ///   [SpokeRegistration]s supporting priority and pattern matching.
  /// * [routing]: **Match Strategy.** Defines evaluation logic:
  ///   [HubRouting.exact], [HubRouting.pattern], or [HubRouting.prefix].
  /// * [multicast]: **Broadcast Mode.** If `true`, delivers signals to *all*
  ///   matching spokes instead of just the highest priority.
  /// * [fallback]: **Default Route.** The key of the spoke used when no matches
  ///   are identified.
  /// * [source]: **Ingress Source.** An optional upstream [Cell] that
  ///   automatically feeds the hub.
  ///
  /// ### Returns:
  /// A [HubHandle] (Record) providing:
  /// * `cell`: The central routing [Cell] instance (The Observable).
  /// * `emit`: A synchronous gateway for manual signal injection.
  /// * `emitAsync`: An asynchronous, lock-protected version of the emit.
  /// * `ingest`: A high-level ingress handle for standardized orchestration.
  ///
  /// ### See Also:
  /// * [Cell.ingress]: For standard single-path entry points.
  /// * [Cell.open]: For module boundaries requiring manual structural control.
  /// * [HubRouting]: For defining how the hub evaluates pulse types.
  /// - **Example**: See `example/hub_demo.dart` for a complete executable
  ///   walkthrough of pattern matching, priority ordering, and multicast routing.
  /// {@category Core 16 Operators}
  static HubHandle hub({
    Map<String, Pulse? Function(Cell cell, Pulse pulse, {dynamic user})>? spokes,
    Map<DeputyContext, Receptor>? governedSpokes,
    List<SpokeRegistration>? registrations,
    HubRouting routing = HubRouting.exact,
    bool multicast = false, // force broadcast to all matches
    String? fallback, // key used when nothing matches
    Synapses Function(String role)? distribution,
    void Function(Pulse pulse)? relay,
    Cell? source,
  }) =>
      _hub(
        spokes: spokes,
        governedSpokes: governedSpokes,
        registrations: registrations,
        fallback: fallback,
        routing: routing,
        multicast: multicast,
        bind: source,
        distribution: distribution,
        relay: relay,
      );

  /// Synthesizes a **Privacy Guard**—a security-hardened node that
  /// automatically modifies [Pulse] payloads based on their [Sensitivity]
  /// and compliance mandates.
  ///
  /// The [sanitized] factory acts as a sovereign privacy gate within the
  /// reactive network. It ensures that sensitive data—such as PII,
  /// credentials, or internal secrets—is programmatically stripped or
  /// masked before it propagates to less secure layers of the system.
  ///
  /// ### When to use
  /// Use this factory to establish a "Clean Room" boundary. It allows
  /// high-sensitivity data to flow through the core of your application
  /// while ensuring that UI components or loggers only receive safe,
  /// redacted versions of that information.
  ///
  /// - **PII Masking**: Hiding parts of an email or phone number in UI views.
  /// - **Credential Stripping**: Removing API keys or tokens before pulses
  ///   reach a telemetry or logging observer.
  /// - **Compliance Enforcement**: Automatically applying GDPR or HIPAA
  ///   redaction rules based on the signal's metadata.
  ///
  /// ### How it works
  /// 1. The cell establishes a link to the [source] source.
  /// 2. It inspects the [Sensitivity] level of every incoming pulse.
  /// 3. If the sensitivity meets or exceeds the [minSensitivity] threshold,
  ///    the [redact] logic is applied.
  /// 4. The "cleansed" pulse is then propagated to downstream observers.
  ///
  /// ### Non‑obvious
  /// - **Targeted Sanitization**: Redaction happens during the propagation
  ///   phase; the original source cell remains completely intact and
  ///   retains the raw data for authorized internal use.
  /// - **Causal Integrity**: Redacted pulses are generated as `EvolvedPulse`
  ///   instances. This means they preserve their forensic history, allowing
  ///   auditors to see *when* and *why* a value was sanitized.
  /// - **Compliance Defaults**: If a pulse lacks sensitivity metadata, it
  ///   is treated as [Sensitivity.public] and bypasses redaction unless
  ///   configured otherwise.
  ///
  /// ### Example: Email Masking
  /// ```dart
  /// final userView = Cell.sanitized<UserPulse>(
  ///   source: internalUserStore,
  ///   redact: (pulse) => Pulse(
  ///     pulse.payload.copyWith(email: "auth***@domain.com"),
  ///     type: 'ui.safe_view'
  ///   ),
  ///   minSensitivity: Sensitivity.confidential,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [source]: **The Ingress Source.** The upstream [Cell] containing the raw,
  ///   potentially sensitive data.
  /// * [redact]: **The Sanitization Logic.** A function that takes the
  ///   sensitive pulse and returns a masked or redacted version.
  /// * [minSensitivity]: **The Enforcement Threshold.** The [Sensitivity]
  ///   level at which redaction is triggered (defaults to
  ///   [Sensitivity.confidential]).
  ///
  /// ### Returns:
  /// A [Cell] instance acting as a **Privacy-Aware Filter**. It propagates
  /// original signals until the sensitivity threshold is met, at which
  /// point it emits the result of the [redact] logic.
  ///
  /// ### See Also:
  /// * [Sensitivity]: For defining data classification levels.
  /// * [Cell.derive]: For general-purpose projections without sensitivity
  ///   checks.
  /// - **Example**: See `example/sanitized_demo.dart` for a complete
  ///   walkthrough of automated PII redaction and audit trails.
  /// {@category Core 16 Operators}
  static Cell sanitized<P extends Pulse>(Cell source, {
    required P Function(P pulse) redact,
    Sensitivity minSensitivity = Sensitivity.confidential,
  }) {
    final receptor = _Receptor(reaction: (pulse, cell, {user}) {
      final p = pulse as P;
      final sensitivity = p.context.sensitivity;
      if (sensitivity != null && sensitivity.index >= minSensitivity.index) {
        return redact(p);
      }
      return p;
    });
    return Cell(bind: source, receptor: receptor);
  }

  /// Creates an atomic multi-cell transaction with configurable isolation.
  ///
  /// A transaction allows you to group multiple cell updates into a single
  /// atomic unit – either all changes are applied, or none are. This is
  /// essential for maintaining consistency across related cells when
  /// a logical operation spans multiple state atoms.
  ///
  /// ### When to use
  /// Use this when you need to update several cells together atomically.
  /// The simplest usage is:
  /// ```dart
  /// final tx = Cell.transaction();
  /// await tx.begin([accountA, accountB]);
  /// tx.update(accountA, 100);
  /// tx.update(accountB, 200);
  /// await tx.commit();
  /// ```
  ///
  /// Use transactions when:
  /// - Multiple cells must change together (all or nothing).
  /// - You need to read values and base updates on them consistently.
  /// - You want to avoid partial updates that could leave the system
  ///   in an inconsistent state.
  /// - You're implementing financial transfers, inventory adjustments,
  ///   or any operation with invariants across cells.
  ///
  /// ### How it works
  /// 1. **Begin**: Register participants and (optionally) snapshot values.
  /// 2. **Update**: Buffer writes – cells are not actually modified yet.
  /// 3. **Read**: Observe values according to the isolation level.
  /// 4. **Commit**: Acquire locks, validate, apply all changes atomically.
  /// 5. **Rollback**: Discard buffered changes.
  ///
  /// ### Non‑obvious
  /// - Locks are held **only during commit**, not across begin→commit.
  ///   This means you can perform long-running logic between begin and
  ///   commit without holding locks.
  /// - Validation happens during commit, not during update. This allows
  ///   you to stage changes and then decide whether to commit.
  /// - If any validation fails, the entire transaction is rolled back
  ///   automatically – no partial updates.
  /// - The transaction scope is not reentrant – you must commit or
  ///   rollback before starting another transaction.
  ///
  /// ### Parameters:
  /// - [options]: Configuration for isolation level, lock ordering,
  ///   timeout, validation, and application logic. Defaults to
  ///   [TransactionOptions] with `readCommitted` isolation.
  ///
  /// ### Returns:
  /// A [TransactionScope] handle with methods to control the transaction.
  ///
  /// ### Example 1: Basic Transfer
  /// ```dart
  /// final tx = Cell.transaction();
  ///
  /// // Begin with two accounts
  /// await tx.begin([fromAccount, toAccount]);
  ///
  /// // Read current balances
  /// final fromBalance = tx.read(fromAccount) as int;
  /// final toBalance = tx.read(toAccount) as int;
  ///
  /// // Update balances
  /// tx.update(fromAccount, fromBalance - 50);
  /// tx.update(toAccount, toBalance + 50);
  ///
  /// // Commit atomically
  /// await tx.commit();
  /// ```
  ///
  /// ### Example 2: With Savepoint
  /// ```dart
  /// final tx = Cell.transaction();
  /// await tx.begin([cell1, cell2, cell3]);
  ///
  /// tx.update(cell1, 10);
  /// tx.update(cell2, 20);
  ///
  /// // Create a checkpoint
  /// final sp = tx.savepoint();
  ///
  /// // Speculative updates
  /// tx.update(cell2, 30);
  /// tx.update(cell3, 40);
  ///
  /// // Something went wrong – rollback to checkpoint
  /// await tx.rollback(savepoint: sp);
  ///
  /// // cell1 = 10, cell2 = 20, cell3 unchanged
  /// await tx.commit();
  /// ```
  ///
  /// ### Example 3: Repeatable Read Isolation
  /// ```dart
  /// final tx = Cell.transaction(TransactionOptions(
  ///   isolation: IsolationLevel.repeatableRead,
  ///   timeout: Duration(seconds: 5),
  ///   onEvent: (e) => print(e),
  /// ));
  ///
  /// await tx.begin([accountA, accountB]);
  ///
  /// // Both reads return the snapshot from begin
  /// final a = tx.read(accountA) as int;
  /// final b = tx.read(accountB) as int;
  ///
  /// // If another transaction changed accountA after begin,
  /// // commit will throw TransactionConflictException
  /// tx.update(accountA, a + 100);
  /// await tx.commit();
  /// ```
  ///
  /// ### See also:
  /// - [TransactionOptions] – configuration for the transaction.
  /// - [TransactionScope] – the handle returned by this factory.
  /// - [IsolationLevel] – consistency guarantees.
  /// - [TransactionValidationException] – thrown when validation fails.
  /// - [TransactionConflictException] – thrown on isolation conflicts.
  /// - **Example**: See `example/transaction_demo.dart` for a complete executable walkthrough.
  /// {@category Advanced}
  /// {@category Transactions}
  static TransactionScope transaction([
    TransactionOptions options = const TransactionOptions(),
  ]) =>
      _transaction(options);

  /// An Atomic Evolution Sequencer that executes multiple state mutations
  /// within a single coordinated transaction.
  ///
  /// ### When to use:
  /// - **Multi-Cell Consistency**: Updating multiple cells (e.g., a `balance`
  ///   and `ledger`) where partial updates would break graph integrity.
  /// - **Performance Optimization**: Batching high-frequency updates to
  ///   prevent redundant downstream "churn" or multiple UI repaints.
  /// - **Cyclic Dependency Guards**: Coordinating updates that might
  ///   otherwise trigger race conditions if executed in isolation.
  ///
  /// ### How it works:
  /// `txApply` opens a "Transaction Frame." All updates performed within the
  /// scope are staged. Only when the scope completes successfully are the
  /// changes committed and propagated through the reactive graph. If an error
  /// occurs, the staged pulses are discarded (rolled back).
  ///
  /// ### Non‑obvious:
  /// - **Pulse Consolidation**: Downstream cells only observe the *final*
  ///   state of the graph at the end of the transaction, effectively
  ///   debouncing intermediate transitions.
  /// - **Forensic Framing**: All evolutions within the scope are tagged
  ///   with a `TransactionID`, allowing forensic tracers to identify
  ///   mutations belonging to the same atomic block.
  /// - **Reentrancy**: If called inside an existing transaction, it joins
  ///   the parent scope rather than creating a nested one.
  ///
  /// ### Parameters:
  /// - [options]: Configuration including the `action` closure, security
  ///   `context`, conflict `policy`, and whether to `wait` for stabilization.
  ///
  /// ### Returns:
  /// An [ApplyTransactionScope] result indicating success, timing, and
  /// forensic metadata for the committed batch.
  ///
  /// ### See Also:
  /// - [Cell.state]: The primary target for transactional updates.
  /// - [TransactionOptions]: For advanced isolation and locking controls.
  /// - **Example**: See `example/atomic_multi_update.dart` for a
  ///   walkthrough of bank transfer logic and multi-node consistency.
  /// {@category Advanced}
  /// {@category txApply}
  static ApplyTransactionScope txApply([
    TxApplyOptions options = const TxApplyOptions(),
  ]) =>
      _txApply(options);

  /// Synthesizes a **Manual Control Interface**—a specialized node that allows
  /// you to manually push data into the reactive network or change how cells
  /// are connected at runtime.
  ///
  /// The [open] factory creates an **Imperative Gateway**. Unlike most cells
  /// that react automatically to upstream changes, an [OpenCell] acts as a
  /// "Sovereign Port." It is designed for cases where your code needs to bridge
  /// external systems or manually manage the lifecycle of connections while the
  /// app is running.
  ///
  /// ### When to use
  /// - **Dynamic Topology**: Use this when you need an entry point that isn't locked to a single
  ///   source, or when you need to manually `link` and `unlink` observers
  ///   as the state of your application changes.
  /// - **Module Boundaries**: Creating a public API for a module that
  ///   receives external commands.
  /// - **Dynamic Layouts**: Attaching or detaching observers based on
  ///   user navigation or temporary app states.
  /// - **Testing & Simulation**: Manually injecting data pulses to verify
  ///   that downstream logic behaves correctly.
  ///
  /// ### How it works
  /// 1. The factory creates an [OpenCell] with a public [receptor].
  /// 2. **Pushing Data**: Calling `receptor(pulse)` manually sends data into
  ///    the network, provided it passes the [testRule] validation.
  /// 3. **Dynamic Connections**: You can use the `link()` and `unlink()`
  ///    methods to change which cells receive updates at runtime.
  /// 4. **Tracking History**: Any data pushed through the receptor is
  ///    recorded with its origin, allowing you to trace the cause of changes
  ///    back to this specific gateway.
  ///
  /// ### Non‑obvious
  /// - **Security Rules Apply**: Even though this node is "Open," it is not
  ///   a backdoor. All manual data entries must match the [context]
  ///   permissions and pass the safety checks in the [testRule].
  /// - **Connection Authority**: Linking and unlinking other nodes are
  ///   protected actions. A caller must have the correct [Context]
  ///   authority to change the network structure.
  /// - **Hybrid Mode**: If a [bind] source is provided, the cell will relay
  ///   data from that source automatically while *also* accepting your
  ///   manual inputs.
  /// - **Flow Control**: Use the [synapses] parameter to attach a
  ///   [PropagationPolicy]. This allows you to debounce state emissions,
  ///   throttle high-frequency updates, or batch multiple state changes
  ///   into a single downstream pulse.
  ///
  /// ### Example: System Command Gateway
  /// ```dart
  /// final commandGate = Cell.open(
  ///   context: Context.admin,
  ///   receptor: Receptor((cell, pulse, {user}) {
  ///     // Handle manual commands like "SHUTDOWN" or "RESET"
  ///     return pulse;
  ///   }),
  /// );
  ///
  /// // Manually push a pulse from a UI button or admin console
  /// commandGate.emit(Pulse('SHUTDOWN', type: 'system.command'));
  /// ```
  ///
  /// ### Parameters:
  /// * [ephemeralPolicy]: **Lifecycle Management.** Defines how the node
  ///   is cleaned up when it is no longer being used.
  /// * [context]: **Operational Authority.** The security and priority tier
  ///   that governs manual data entry and connection changes.
  /// * [bind]: **Ingress Source.** An optional cell to watch automatically.
  /// * [receptor]: **The Control Port.** The logic that processes your
  ///   manual data injections. Defaults to passing data through as-is.
  /// * [testRule]: **Integrity Gate.** A safety check that validates
  ///   both manual pulses and requests to link/unlink new cells.
  /// * [synapses]: **Egress Network.** Configures how data is initially
  ///   distributed to other parts of the app.
  /// * [forceLock]: **Atomic Isolation.** If `true`, ensures that manual
  ///   inputs are processed one at a time in a safe, isolated block.
  ///
  /// ### Returns:
  /// An [OpenCell] instance that serves as a governable, manual gateway.
  ///
  /// ### Example:
  /// See `example/open_cell_demo.dart` for a complete walkthrough of manual signal injection and dynamic topology control.
  ///
  /// ### See Also:
  /// * [Cell.ingress]: For standard, single-path entry points.
  /// * [Cell.hub]: For routing manual signals to multiple specific handlers.
  /// {@category Core 16 Operators}
  static OpenCell open({
    EphemeralPolicy? ephemeralPolicy,
    Context context = Context.system,
    Cell? source,
    Receptor receptor = Receptor.passThrough,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    bool forceLock = false,
  }) {
    return OpenCell.governed(
      context: context,
      ephemeralPolicy: ephemeralPolicy,
      bind: source,
      receptor: receptor,
      testRule: testRule,
      synapses: synapses,
      forceLock: forceLock,
    );
  }

  /// Synthesizes a **Multi-Source Convergence Node**—the primary primitive
  /// for merging disparate data streams into a unified reactive output.
  ///
  /// The [synthesis] factory treats a collection of [sources] as a single
  /// dependency unit. Whenever *any* source cell emits a signal, the
  /// synthesis cell reacts, aggregates the current state of the network,
  /// and propagates a new converged pulse.
  ///
  /// ### When to use
  /// - **Data Fusion**: Combining multiple sensor readings (e.g., Temperature,
  ///   Humidity, Pressure) into a single "EnvironmentStatus" object.
  /// - **Form Validation**: Monitoring multiple input cells to determine if
  ///   a "Submit" button should be enabled.
  /// - **Coordinated UI**: Merging different state atoms (e.g., `userPrefs`
  ///   and `themeState`) to drive a single view component.
  /// - **Consensus Logic**: Implementing "all-or-nothing" triggers that
  ///   require valid data from all sources before proceeding.
  ///
  /// ### How it works
  /// 1. **Subscription**: The cell establishes a permanent reactive link to
  ///    every cell in the [sources] iterable.
  /// 2. **Reaction**: When any source emits a [Pulse], the synthesis node
  ///    intercepts the signal.
  /// 3. **Aggregation**: The [aggregator] function is invoked. It receives
  ///    the full set of cells (for inspection of current values) and the
  ///    specific `emit` pulse that triggered the current update cycle.
  /// 4. **Convergence**: The resulting pulse from the aggregator is
  ///    broadcast to all downstream [Synapses].
  ///
  /// ### Non‑obvious
  /// - **Pulse Awareness**: The `aggregator` has access to the specific
  ///   `emit` pulse, allowing logic to differ based on *which* source
  ///   triggered the update or what metadata that source provided.
  /// - **Transaction Safety**: If multiple sources are updated within a
  ///   single [Cell.transaction], the [aggregator] fires exactly once at
  ///   the end of the transaction, preventing intermediate "glitches."
  /// - **Statelessness**: A synthesis cell does not store its own history;
  ///   it acts as a functional projection of its sources' current values.
  ///
  /// ### Example: Total Price Calculation
  /// ```dart
  /// final total = Cell.synthesis<Pulse<double>>(
  ///   [price, tax, shipping],
  ///   aggregator: (sources, pulse) {
  ///     final p = (sources.elementAt(0) as ValueCell<double>).value;
  ///     final t = (sources.elementAt(1) as ValueCell<double>).value;
  ///     final s = (sources.elementAt(2) as ValueCell<double>).value;
  ///     return Pulse(p + t + s);
  ///   },
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [sources]: **Ingress Set.** The collection of upstream cells to monitor.
  /// * [aggregator]: **Convergence Logic.** A function that takes the
  ///   `cells` (sources) and the triggering `emit` pulse to produce the
  ///   merged output. Returning `null` suppresses the emission.
  ///
  /// ### Returns:
  /// A [Cell] instance representing the converged reactive state of all
  /// provided [sources].
  ///
  /// ### See Also:
  /// - [Cell.derive]: For simple 1-to-1 transformations of a single source.
  /// - **Example**: See `example/synthesis_demo.dart` for a walkthrough
  ///   of information convergence.
  /// - **HowTo**: See `guide/HowTo_Start.md` for patterns on managing
  ///   complex information convergence.
  /// {@category Core 16 Operators}
  static Cell synthesis<P extends Pulse>(
    Iterable<Cell> sources, {
    required P? Function(Iterable<Cell> cells, Pulse emit) aggregator,
  }) {
    final receptor = _Receptor(reaction: (pulse, cell, {user}) => aggregator(sources, pulse));
    return SynthesisCell(sources, receptor: receptor);
  }

  /// Synthesizes a **Conditional Gate**—a specialized node that acts as a
  /// reactive circuit breaker, controlling signal propagation through the graph.
  ///
  /// The [valve] factory is the primary mechanism for **Dynamic Graph Pruning**.
  /// It intercepts incoming stimuli from a source and, based on its internal
  /// [gate] logic, decides whether to "Open" (propagate) or "Close" (suppress).
  ///
  /// ### When to use
  /// - **Conditional Flow**: Control signal propagation based on payload
  ///   content or forensic metadata (e.g., source authority).
  /// - **Validation**: Suppress pulses that do not meet business rules or
  ///   integrity constraints before they reach expensive downstream effects.
  /// - **Dynamic Pruning**: Disconnect reactive branches when system
  ///   conditions (like "Maintenance Mode") are met.
  /// - **Noise Filtering**: Blocking signals that contain redundant or
  ///   irrelevant information for a specific sub-graph.
  ///
  /// ### How it works
  /// 1. **Stimulus**: The valve monitors the [source] for any incoming [Pulse].
  /// 2. **Evaluation**: Upon receiving a pulse, the [gate] predicate is
  ///    executed immediately.
  /// 3. **Decision**:
  ///    - If `true`, the gate is **Open** and the original pulse is forwarded
  ///      to the [synapses] layer.
  ///    - If `false`, the gate is **Closed** and the pulse is discarded
  ///      (**Signal Termination**).
  /// 4. **Egress**: Pulses that pass the gate are subject to the [synapses]
  ///    configuration (e.g., [Cell.debounce]) before reaching observers.
  ///
  /// ### Non‑obvious
  /// - **Statelessness**: A valve is a reactive conduit, not a state holder.
  ///   It does not remember the last passed value. To filter based on
  ///   value history, use [Cell.distinct].
  /// - **Early Termination**: Because the valve sits upstream of its own
  ///   synapses, a closed gate prevents propagation strategies (like
  ///   debounce timers) from even being triggered.
  /// - **Forensic Audit**: Even suppressed pulses remain visible to the
  ///   switching fabric's forensic hooks if the [Context] is configured
  ///   for full observability.
  /// - **Type Safety**: The [gate] function is generic over [P], allowing
  ///   specialized inspection of custom [Pulse] subclasses or metadata.
  ///
  /// ### Example: Content-Based Filter
  /// ```dart
  /// // Only allow non-empty search strings to reach the API caller
  /// final searchValve = Cell.valve<Pulse<String>>(
  ///   (pulse) => pulse.payload!.trim().isNotEmpty,
  ///   source: rawInputCell,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [gate]: **The Boolean Gate.** A predicate function that inspects the
  ///   incoming pulse. Returning `true` allows the signal to pass.
  /// * [source]: **The Ingress Source.** The upstream [Cell] to be screened.
  /// * [synapses]: **Egress Network.** Configures routing, timing, and
  ///   distribution behavior for pulses that survive the gate.
  ///
  /// ### Returns:
  /// A [Cell] instance acting as a **Reactive Circuit Breaker**.
  ///
  /// ### See Also:
  /// * [Cell.distinct]: For filtering consecutive duplicate values.
  /// * [Cell.debounce]: For filtering signals based on temporal stability.
  /// - **Example**: See `example/valve_demo.dart` for a complete walkthrough
  ///   of conditional signal suppression.
  /// {@category Core 16 Operators}
  static Cell valve<P extends Pulse>(
      Cell source,
      bool Function(P pulse) gate, {
        Synapses synapses = Synapses.enabled
      }) {
    final receptor = _Receptor(reaction: (pulse, cell, {user}) => gate(pulse as P) ? pulse : null);
    return Cell.governed(receptor: receptor, bind: source, synapses: synapses);
  }

  /// Limits propagation by waiting for a period of stability in the [source]
  /// (classic Rx `debounceTime`).
  ///
  /// The `debounce` gate acts as a **Temporal Filter**, suppressing a rapid
  /// succession of signals and only allowing a pulse to pass once the upstream
  /// source has remained quiescent for a specified duration.
  ///
  /// ### When to use
  /// Use `debounce` when you want to ignore intermediate states in a burst of
  /// activity and only react to the "final" or stable state.
  ///
  /// - **Search Bars**: Waiting for a user to stop typing before initiating
  ///   a network-heavy search query.
  /// - **Form Validation**: Triggering expensive validation logic only after
  ///   the user has finished editing a field.
  /// - **Auto-Save**: Persisting data to a database once a burst of edits
  ///   has ceased.
  /// - **Noise Reduction**: Filtering out jitter from high-frequency sensor
  ///   data where only the settled value is relevant.
  ///
  /// ### How it works
  /// 1. **Stimulus**: When the [source] emits a pulse, the debounce node
  ///    starts an internal timer for the specified [duration].
  /// 2. **Interruption**: If a new pulse arrives before the timer expires,
  ///    the previous timer is cancelled and a new one starts from zero.
  /// 3. **Settling**: Only when the timer reaches the end of the [duration]
  ///    window without interruption is the latest pulse propagated.
  ///
  /// ### Non‑obvious
  /// - **Leading Edge**: If [leading] is `true`, the *first* pulse in a burst
  ///   is emitted immediately, and subsequent pulses are debounced until the
  ///   silence window is met.
  /// - **Wait vs Throttle**: Unlike [Cell.throttle] (which limits frequency),
  ///   `debounce` requires a specific period of *silence* before emission.
  /// - **Graph Stabilization**: The debounce gate effectively introduces a
  ///   delay in the reactive graph, so downstream nodes will observe changes
  ///   later than they occur at the source.
  ///
  /// ### Parameters:
  /// * [source]: **The Ingress Source.** The upstream [Cell] to be monitored
  ///   for stability.
  /// * [duration]: **The Stability Window.** The period of silence required
  ///   before the signal is allowed to propagate.
  /// * [leading]: **Initial Feedback.** If `true`, the first pulse of a burst
  ///   is propagated immediately. Defaults to `false`.
  ///
  /// ### Returns:
  /// A [Cell] instance representing a **Stability Filter**. It only
  /// propagates signals after the [source] has remained stable for the
  /// specified [duration].
  ///
  /// ### See Also:
  /// * [Cell.throttle]: For frequency-based rate limiting (constant output rate).
  /// - **Example**: See `example/stability_search_demo.dart` for a complete
  ///   walkthrough of user-input stabilization and debounced API calls.
  /// - **HowTo**: See `guide/HowTo_Start.md` for a comprehensive guide on
  ///   reactive patterns and scheduling.
  /// {@category Core 16 Operators}
  static Cell debounce(
    Cell source,
    Duration duration, {
    bool leading = false,
  }) => _debounce(
        source,
        duration,
        leading: leading,
      );

  /// Limits the frequency of updates from a [source] cell by enforcing a
  /// minimum [duration] between emissions.
  ///
  /// ### When to use
  /// Use `throttle` when you need to sample a high-frequency stream of signals
  /// at a predictable, constant rate.
  ///
  /// - **UI Performance**: Limiting scroll or mouse-move events to 60fps.
  /// - **API Rate Limiting**: Ensuring a "save" operation happens at most
  ///   once every 2 seconds.
  /// - **Constant Updates**: Monitoring a fast-changing sensor where you only
  ///   need periodic snapshots.
  ///
  /// ### Choosing Between Sampling Patterns:
  /// * **[Cell.debounce]**: (Stability-based) Waits for N ms of silence.
  ///   Best for "finality" signals and reducing redundant operations.
  /// * **[Cell.throttle]**: (Frequency-based) Limits output to one pulse per
  ///   N ms. Best for maintaining a constant-rate update.
  ///
  /// ### How it works
  /// 1. **Initial Emission**: If [leading] is `true`, the first pulse received
  ///    is emitted immediately.
  /// 2. **Silent Window**: A timer starts for [duration]. During this time,
  ///    new pulses are either ignored or buffered depending on [trailing].
  /// 3. **Trailing Emission**: If [trailing] is `true` and pulses were
  ///    received during the window, the last pulse is emitted automatically
  ///    once the timer expires.
  /// 4. **Reset**: Once the window closes (and the optional trailing pulse is
  ///    sent), the cycle resets.
  ///
  /// ### Non‑obvious:
  /// * **Leading vs. Trailing**: By default, `leading` is true and `trailing`
  ///   is false. This ensures immediate feedback for the first user action
  ///   while suppressing the subsequent burst.
  /// * **Resource Management**: The internal timer is automatically managed
  ///   and cleaned up when the cell is disposed or its context is revoked.
  ///
  ///
  /// ### Example:
  /// See `example/throttle_demo.dart` for a practical executable walkthrough.
  ///
  /// ### Parameters:
  /// * [source]: The upstream Cell to monitor for updates.
  /// * [duration]: The minimum time between emissions.
  /// * [leading]: If `true`, the first pulse of a burst is emitted immediately.
  /// * [trailing]: If `true`, the last pulse of a burst is emitted after
  ///   the duration expires.
  ///
  /// ### Returns:
  /// A [Cell] that enforces a rate-limit on signal propagation from the [source].
  ///
  /// ### See Also:
  /// * [Cell.debounce]: For stability-based rate limiting.
  /// - **Example**: See `example/throttle_demo.dart` for a
  ///   walkthrough of frequency-based rate limiting.
  /// {@category Core 16 Operators}
  static Cell throttle(
    Cell source,
    Duration duration, {
    bool leading = true,
    bool trailing = false,
  }) =>
      _throttle(
        source,
        duration,
        leading: leading,
        trailing: trailing
      );

  /// Filters out consecutive duplicate payloads from a source [Cell].
  ///
  /// ### When to use
  /// - **Performance Tuning**: Preventing redundant calculations or network
  ///   requests when inputs remain the same.
  /// - **UI Stability**: Avoiding flickers or unnecessary refreshes in
  ///   views that observe high-frequency but stable data.
  /// - **Sensor Normalization**: Filtering out "heartbeat" pulses from
  ///   hardware that report the same value repeatedly.
  /// - **Logical Deduplication**: Ensuring a state machine only processes
  ///   transitions that move to a new, different state.
  ///
  /// ### How it works
  /// 1. The cell maintains a reference to the last successfully emitted
  ///    payload.
  /// 2. Every incoming pulse is compared against this stored value using
  ///    the [equals] function.
  /// 3. If the [equals] check returns `true`, the pulse is dropped (signal
  ///    termination).
  /// 4. If the check returns `false`, the new value is stored and the
  ///    pulse is forwarded.
  ///
  /// ### Non‑obvious
  /// - **Consecutive Only**: Suppression only applies to back-to-back
  ///   duplicates. A sequence `1, 2, 1` will emit three times.
  /// - **Initial Emission**: The first pulse is always allowed as there is
  ///   no previous value for comparison.
  /// - **Payload Scoped**: Equality checks apply strictly to the `payload`;
  ///   forensic metadata (timestamps, sources) is ignored.
  /// - **Custom Equality**: Providing an [equals] function allows for deep
  ///   equality, case-insensitive comparison, or numeric tolerance bands.
  /// - **Null Handling**: Consecutive `null` payloads are treated as
  ///   duplicates by the default `==` operator.
  ///
  /// ### Example
  /// ```dart
  /// final search = Cell.ingress<String>();
  ///
  /// final uniqueTerms = Cell.distinct(search.cell);
  ///
  /// Cell.observe(
  ///   source: uniqueTerms,
  ///   effect: (p) => print('new search: ${p.payload}'),
  /// );
  ///
  /// search.emit('dart'); // → prints "new search: dart"
  /// search.emit('dart'); // (suppressed)
  /// search.emit('flutter'); // → prints "new search: flutter"
  /// search.emit('flutter'); // (suppressed)
  /// search.emit('dart'); // → prints "new search: dart"
  /// ```
  ///
  /// ### Parameters:
  /// * [source]: **The Ingress Source.** The cell whose payloads will be
  ///   filtered for duplicates.
  /// * [equals]: **Equality Predicate.** A function defining what
  ///   constitutes a duplicate. Defaults to `==`.
  ///
  /// ### Returns:
  /// A [Cell] that only emits when the upstream payload differs from the
  /// previous one.
  ///
  /// ### See Also:
  /// - [Cell.state]: For complex predicate-based filtering.
  /// - **Example**: See `example/distinct_demo.dart` for a walkthrough
  ///   of noise reduction.
  /// - **HowTo**: See `guide/HowTo_17_Essential_Operators.md` for best
  ///   practices on filtering and flow control.
  /// {@category Core 16 Operators}
  static Cell distinct(
    Cell source, {
    bool Function(dynamic previous, dynamic next)? equals,
  }) =>
      _distinct(source, equals: equals);

  /// Synthesizes an **Asynchronous Data Transformer**—a specialized node that
  /// runs background tasks for every emission from an upstream source.
  ///
  /// In the framework's reactive network, the [asyncMap] factory acts as an
  /// **Active Bridge**. It allows you to perform long-running operations—like
  /// network requests, database queries, or heavy computations—without blocking
  /// the main reactive flow.
  ///
  /// ### When to use
  /// - **Remote Data Fetching**: Fetching JSON from an API whenever a selection
  ///   changes.
  /// - **Async Validation**: Checking a username's availability against a
  ///   server before proceeding.
  /// - **Heavy Computation**: Running complex logic that should stay off the
  ///   primary execution thread.
  /// - **Sequential Enrichment**: Fetching "Step 2" data only after "Step 1"
  ///   has successfully emitted.
  /// - **Data Enrichment**: Turn a simple ID or command into a complex
  ///   object that requires a `Future` to fetch (e.g., turning a `userId` into
  ///   a `UserProfile`).
  ///
  /// ### How it works
  /// 1. The cell monitors the [source] for new data pulses.
  /// 2. Every incoming payload is passed to the [mapper] function, which
  ///    returns a [Future].
  /// 3. **Concurrency Control**: Based on your settings, the cell manages how
  ///    many futures run at once (see Concurrency below).
  /// 4. When a future completes, its result is wrapped in an [EvolvedPulse]
  ///    and broadcast to observers.
  ///
  /// ### Concurrency Modes
  /// * **Parallel (Default)**: Set [concurrency] to `0`. All futures run as
  ///   soon as they are triggered. Results are emitted as soon as they finish.
  /// * **Sequential**: Set [concurrency] to `1`. The cell waits for the
  ///   current future to finish before starting the next one.
  /// * **Throttled**: Set [concurrency] to a specific number (e.g., `3`) to
  ///   limit how many background tasks run simultaneously.
  /// * **Switching**: Set [latestOnly] to `true`. If a new signal arrives
  ///   while a future is still running, the old future is ignored and only
  ///    the most recent one will emit.
  ///
  /// ### Non‑obvious
  /// - **Causal Integrity**: Even though the result arrives later, the
  ///   [EvolvedPulse] tracks the original stimulus, preserving the forensic
  ///   trail across the asynchronous boundary.
  /// - **Error Handling**: If the [mapper] throws an error or the future fails,
  ///   the signal is terminated to prevent corrupted data from entering the
  ///   reactive network.
  /// - **Order Preservation**: In parallel mode ([concurrency] `0`), results
  ///   might arrive out of order if the second task finishes faster than the
  ///   first. Use [concurrency] `1` if order is critical.
  ///
  /// ### Choosing Between Transformations: asyncMap vs. switchMap
  /// While both factories handle asynchronous logic, they serve different
  /// purposes in the reactive graph:
  ///
  /// - **[Cell.asyncMap]** is for **Background Tasks**. The [mapper] returns
  ///   a `Future`. Use this when you want to take an input and perform a
  ///   discrete, long-running action (like a calculation or a specific
  ///   network request) that results in a single value.
  ///
  /// - **[Cell.switchMap]** is for **Dynamic Routing**. The [mapper] returns
  ///   a `Cell`. Use this when you want to switch your entire subscription
  ///   to a new "live" stream of data based on a selection.
  ///
  /// **Summary**: Use [asyncMap] for a background job; use [switchMap] to
  /// pick a new live data source.
  ///
  /// ### Example: Profile Loader
  /// ```dart
  /// final userId = Cell.ingress<int>();
  ///
  /// final profile = Cell.asyncMap<int, UserProfile>(
  ///   userId.cell,
  ///   (id) => api.fetchProfile(id),
  ///   latestOnly: true, // Only care about the user most recently clicked
  /// );
  /// ```
  ///
  /// ### Example (exhaust)
  /// ```dart
  /// final clicks = Cell.ingress<void>();
  /// final saves = Cell.asyncMap<void, String>(
  ///   clicks.cell,
  ///   (_) async {
  ///     await Future.delayed(const Duration(milliseconds: 200));
  ///     return 'saved';
  ///   },
  ///   exhaust: true,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [source]: **The Stimulus Source.** The cell providing the input values.
  /// * [mapper]: **The Async Logic.** A function that returns a [Future] for
  ///   each input.
  /// * [concurrency]: **Flow Limit.** How many futures to run at once.
  ///   `0` = unlimited, `1` = one at a time.
  /// * [latestOnly]: **Discard Policy.** If `true`, only the result of the
  ///   most recent input is emitted.
  /// * [exhaust] – exhaustMap-style (ignore upstream while busy)
  ///
  /// ### Returns:
  /// A [Cell] instance representing an **Asynchronous Transformation**. It
  /// emits the resolved results of the background tasks.
  ///
  /// ### Example:
  /// See `example/async_map_demo.dart` for a complete walkthrough of concurrent background tasks.
  ///
  /// ### See Also:
  /// * [Cell.switchMap]: To switch to a different source cell entirely.
  /// * [Cell.fromFuture]: To bridge a single, one-time async result.
  /// {@category Core 16 Operators}
  static Cell asyncMap<S, T>(
    Cell source,
    Future<T> Function(S value) mapper, {
    int concurrency = 0,
    bool latestOnly = false,
    bool exhaust = false,
  }) =>
      _asyncMap<S, T>(
        source,
        mapper,
        concurrency: concurrency,
        latestOnly: latestOnly,
        exhaust: exhaust,
      );

  /// Creates a [Cell] that emits the values produced by a Dart [Stream].
  ///
  /// The [fromStream] factory acts as an **External Event Ingress**. It
  /// allows you to bridge asynchronous data sources—such as WebSockets,
  /// hardware sensors, or file watchers—into the  cell graph, where they can
  /// be transformed and observed like any other signal.
  ///
  /// ### When to use
  /// Use [fromStream] when you need to bridge an existing asynchronous
  /// [Stream] (WebSocket, file watcher, `Stream.periodic`, third-party SDK,
  /// etc.) into the Cell reactive graph. Typical scenarios:
  /// - **External Integration**: Bringing data from third-party SDKs or
  ///   native platform channels into the reactive graph.
  /// - **Periodic Events**: Handling timers or clock ticks (`Stream.periodic`).
  /// - **Live Feeds**: Observing real-time updates from a database or
  ///   network socket.
  ///
  /// Prefer [fromFuture] when you have a single asynchronous value rather
  /// than a continuous sequence. Prefer [Cell.ingress] when the events are
  /// generated by imperative callbacks rather than a [Stream].
  ///
  /// ### How it works
  /// 1. A governed cell is created with a pass-through receptor.
  /// 2. The supplied [stream] is listened to.
  /// 3. Every data event is wrapped in a [Pulse] and fed into the cell’s
  ///    receptor, making it available to all downstream observers.
  /// 4. The subscription is automatically cancelled when the cell is
  ///    invalidated (or when the stream closes / errors, depending on
  ///    [cancelOnError]).
  ///
  /// The factory returns a normal [Cell]; you can freely `bind` it, observe it,
  /// or compose it with any other factory.
  ///
  /// ### Non‑obvious
  /// - **No Replay**: The cell only emits values that arrive *after* it has
  ///   been created. It does not store or "remember" past stream events.
  /// - **Causal Origin**: Pulses generated from this factory mark the
  ///   resulting cell as their forensic `source`, allowing you to trace
  ///   external events back to this specific bridge.
  /// - **Error Handling**: By default, stream errors are ignored to prevent
  ///   breaking the reactive graph. Set [cancelOnError] to `true` to
  ///   terminate the bridge if the source stream fails.
  /// - **Backpressure**: Use the [synapses] parameter to apply a
  ///   [PropagationPolicy] (like `debounce` or `throttle`) if the source
  ///   stream produces data faster than your application needs to process it.
  ///
  /// ### Example: Clock Bridge
  /// ```dart
  /// final seconds = Cell.fromStream<int>(
  ///   Stream.periodic(Duration(seconds: 1), (i) => i),
  /// );
  ///
  /// Cell.observe(
  ///   source: seconds,
  ///   effect: (pulse) => print("Tick: ${pulse.payload}"),
  /// );
  ///
  /// // prints "tick: 0", "tick: 1", "tick: 2", … every second
  /// ```
  ///
  /// ### Parameters:
  /// * [stream]: **The External Source.** The Dart [Stream] to be bridged.
  /// * [ephemeralPolicy]: **Lifecycle Management.** Defines how the node
  ///   is disposed of or invalidated when no longer in use.
  /// * [context]: **Operational Authority.** The security and priority tier
  ///   governing the stream ingress (defaults to [Context.system]).
  /// * [testRule]: **Integrity Gate.** A validation check that must pass
  ///   before a stream event is broadcast to the network.
  /// * [synapses]: **Egress Network.** Configures distribution behavior and
  ///   flow control (e.g., throttling) for the stream data.
  /// * [forceLock]: **Atomic Isolation.** If `true`, ensures that stream
  ///   events are processed within a dedicated lock.
  /// * [cancelOnError]: **Termination Policy.** If `true`, the bridge stops
  ///   working if the underlying stream emits an error.
  ///
  /// ### Returns:
  /// A [Cell] instance representing an **Asynchronous Relay**. It emits
  /// whenever the source [stream] produces a new value.
  ///
  /// ### See Also:
  /// * [Cell.fromFuture]: To bridge a single asynchronous result.
  /// * [Cell.ingress]: For manual, callback-based data entry.
  /// - **Example**: See `example/stream_bridge_demo.dart` for a complete
  ///   walkthrough of bridging external real-time data.
  /// {@category Core 16 Operators}
  static Cell fromStream<T>(
    Stream<T> stream, {
    bool cancelOnError = false,
  }) =>
      _fromStream<T>(stream, cancelOnError: cancelOnError);

  /// Creates a [Cell] that emits the result of a [Future] exactly once.
  ///
  /// ### When to use
  /// Use [fromFuture] when you have a single asynchronous computation and
  /// want its result to participate in the Cell reactive graph. Typical
  /// scenarios:
  /// - Loading an initial configuration or user profile
  /// - Waiting for a one-shot network request or database query
  /// - Bridging an existing `async` API into a cell that other cells can
  ///   derive from or observe
  ///
  /// Prefer [fromStream] when the source produces a continuous sequence of
  /// values. Prefer [Cell.ingress] when the value is generated by an
  /// imperative callback rather than a [Future].
  ///
  /// ### How it works
  /// 1. A governed cell is created with a pass-through receptor.
  /// 2. The supplied [future] is awaited.
  /// 3. When the future completes successfully, its value is wrapped in a
  ///    [Pulse] and fed into the cell’s receptor.
  /// 4. Downstream observers receive that single emission; the cell then
  ///    remains silent unless invalidated and recreated.
  ///
  /// The factory returns a normal [Cell]; you can freely `bind` it, observe it,
  /// or compose it with any other factory.
  ///
  /// ### Non‑obvious
  /// - The cell emits **at most once**. If you need the value to stay
  ///   available for late subscribers, wrap the result with [Cell.state] or
  ///   use a [Synapses] policy with `PropagationStrategy.persistent`.
  /// - If the future completes with an error, the error is swallowed by
  ///   default and the cell never emits. You can observe the error by
  ///   attaching your own `catchError` before calling this factory, or by
  ///   extending the implementation to surface a dedicated error pulse.
  /// - If the cell is invalidated before the future completes, the result is
  ///   discarded and no pulse is emitted.
  /// - The pulse’s `source` is set to the cell itself, which is useful for
  ///   tracing and debugging.
  /// - The cell stays alive after the emission; invalidate it explicitly if
  ///   you want it reclaimed.
  /// - **Flow Control**: Use the [synapses] parameter to attach a
  ///   [PropagationPolicy]. This allows you to debounce state emissions,
  ///   throttle high-frequency updates, or batch multiple state changes
  ///   into a single downstream pulse.
  ///
  /// ### Example
  /// ```dart
  /// Future<String> loadUserName() async {
  ///   await Future.delayed(const Duration(milliseconds: 300));
  ///   return 'Alice';
  /// }
  ///
  /// final userName = Cell.fromFuture<String>(loadUserName());
  ///
  /// Cell.observe(
  ///   source: userName,
  ///   effect: (Pulse p, {user}) => print('loaded: ${p.payload}'),
  /// );
  ///
  /// // after 300 ms → prints "loaded: Alice"
  /// ```
  ///
  /// ### Parameters
  /// * [future] – the [Future] whose result will be emitted by the cell.
  ///
  /// ### See Also:
  /// * [Cell.fromStream]: For continuous asynchronous data sources.
  /// * [Cell.ingress]: For manual, callback-driven data entry.
  /// - **Example**: See `example/async_bridge_demo.dart` for a walkthrough
  ///   of bridging legacy async APIs into forensic pipelines.
  /// {@category Core 16 Operators}
  static Cell fromFuture<T>(
    Future<T> future) =>
      _fromFuture<T>(future);

  /// Synthesizes a **Dynamic Provider Switch**—a specialized node that
  /// swaps its data source at runtime based on the selection from another cell.
  ///
  /// The [switchMap] factory acts as an **Active Router**. It creates a
  /// "Pluggable Bridge" that unlinks from its previous data source and links to
  /// a new one whenever the [source] cell emits a fresh signal.
  ///
  /// ### When to use
  /// - **Dynamic Profiles**: Switching between different user accounts or
  ///   settings modules where each selection represents a unique state tree.
  /// - **Scoped Data**: Changing an API endpoint or database query whenever
  ///   a search term or category changes.
  /// - **Nested States**: Accessing a sub-property that is itself a cell,
  ///   where the parent cell might change.
  ///
  /// ### How it works
  /// 1. **Triggering**: The factory creates an output cell that listens to the [source].
  /// 2. **Mapping**: When the source emits, the [mapper] is called with the
  ///    new payload to produce a new "inner" cell.
  /// 3. **Rebinding**: The output cell automatically unlinks from the previous
  ///    inner cell and links to the new one.
  /// 4. **Relaying**: Every pulse from the currently active inner cell is
  ///    forwarded to the output cell's synapses.
  ///
  /// ### Non‑obvious
  /// - **Relay Only**: This cell does not emit the values from the [source];
  ///   it only emits values from the cell returned by the [mapper].
  /// - **Automatic Cleanup**: When the source changes, the link to the
  ///   previous inner cell is severed automatically, preventing signal leaks
  ///   from inactive sources.
  /// - **Termination**: If [mapper] returns a cell that is currently silent,
  ///   this switch will also be silent until that inner cell emits.
  /// - **Causal Integrity**: Forwarded pulses preserve their forensic history,
  ///   tracing back through the inner cell to the switch trigger.
  ///
  /// ### Design Note: Source Selection vs. Background Enrichment
  /// * **[Cell.switchMap]** is for **Source Selection**. The [mapper] must
  ///   return a `Cell`. It is used to redirect the flow of data—like tuning a
  ///   radio to a different station.
  /// * **[Cell.asyncMap]** is for **Background Enrichment**. The [mapper]
  ///   returns a `Future`. It is used for one-time async operations—like
  ///   ordering a delivery and waiting for the result.
  ///
  /// ### Example: User Profile Switcher
  /// ```dart
  /// final selectedId = Cell.state<int>(initial: 1);
  ///
  /// // Switch to a new profile cell whenever the ID changes
  /// final profile = Cell.switchMap<int, Profile>(
  ///   selectedId.cell,
  ///   (id) => getProfileCellFor(id),
  /// );
  ///
  /// // Changing the ID automatically swaps the data source for 'profile'
  /// selectedId.emit(2);
  /// ```
  ///
  /// ### Parameters:
  /// * [source]: **The Switch Trigger.** The cell that decides when to
  ///   change the data source.
  /// * [mapper]: **The Provider Logic.** A function that takes the new
  ///   selection and returns the next [Cell] to listen to.
  /// * [ephemeralPolicy]: **Lifecycle Management.** Defines how the node
  ///   is cleaned up when it is no longer in use.
  /// * [context]: **Operational Authority.** The security and priority tier
  ///   governing the switch.
  /// * [testRule]: **Integrity Gate.** A validation check that must pass
  ///   before a switch or a forwarded pulse is broadcast.
  /// * [synapses]: **Egress Network.** Configures distribution behavior
  ///   for the forwarded stream.
  /// * [forceLock]: **Atomic Isolation.** If `true`, ensures the switching
  ///   logic is protected by a dedicated lock.
  ///
  /// ### Returns:
  /// A [Cell] instance representing a **Switched Stream**. It forwards
  /// data from whatever cell was last produced by the [mapper].
  ///
  /// ### See Also:
  /// * [Cell.derive]: For 1-to-1 data changes where the source stays the same.
  /// * [Cell.hub]: For routing a single signal to multiple destinations.
  /// * [Cell.asyncMap]: For enrichment via asynchronous futures.
  /// - **Example**: See `example/switch_map_demo.dart` for a walkthrough
  ///   of dynamic dependency injection.
  /// - **HowTo**: See `guide/HowTo_17_Essential_Operators.md` for best practices
  ///   on using switching and routing operators.
  /// {@category Core 16 Operators}
  static Cell switchMap<S, T>(
    Cell source,
    Cell Function(S value) mapper,
  ) =>
      _switchMap(source, mapper);

  /// Creates a **deputy**: a proxy [Cell] that shares the same underlying
  /// state and identity as this cell, but operates under a different
  /// [context] and/or [testRule].
  ///
  /// A deputy is not a copy. It points at the same physical storage and
  /// [Lock] as its principal — `cell == cell.deputy()` is always `true`, and
  /// changes to one are visible through the other. What differs is *what the
  /// deputy is allowed to do*: [testRule] governs it, and it is layered
  /// *additively* on top of the principal's own rule, so a deputy can only
  /// narrow permissions, never grant ones the principal doesn't already have.
  ///
  /// ### When to use
  /// Use this to create restricted views of a cell – e.g. read‑only, scoped
  /// authority, temporary access, or sandboxed simulations.
  ///
  /// ### How it works
  /// - [testRule]: additional restrictions (layered on top of principal's).
  /// - [context]: the deputy's own mandate (authority, clearance, lease).
  /// - [ephemeralPolicy]: independent lifecycle for this handle.
  /// - [synapses]: independent observer registry for this handle.
  ///
  /// ### Non‑obvious
  /// - The deputy's [testRule] is *added* to the principal's – you cannot
  ///   bypass the principal's own rules.
  /// - Deputies are equal to their principal: `deputy == principal` is `true`.
  ///
  /// ### Example: read-only view
  /// ```dart
  /// final readOnly = await cell.deputy(testRule: TestCell.readOnly);
  /// readOnly.value;        // works
  /// readOnly.apply(...);   // blocked — modifiable whitelist is empty for readOnly
  /// ```
  ///
  /// ### Parameters:
  /// * [context]: The deputy's [DeputyContext] — its authority, role, and
  ///   clearance. Defaults to [DeputyContext.system] (inherits the
  ///   principal's identity, tagged as a delegate).
  /// * [testRule]: Additional [TestCell] policy, layered on top of (not
  ///   replacing) the principal's own rule. Defaults to [TestCell.allowAll]
  ///   (no additional restriction beyond the principal's).
  /// * [ephemeralPolicy]: Optional TTL/event-count lifecycle for this
  ///   specific handle, independent of the principal's own lifecycle.
  /// * [synapses]: The deputy's own downstream observer registry. Defaults
  ///   to [Synapses.enabled] — a fresh, independent registry, not shared
  ///   with the principal's.
  ///
  /// ### Returns:
  /// A [FutureOr] resolving to a [Cell] sharing this instance's state under
  /// the specified restrictions.
  FutureOr<Cell> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  /// The primary structural gatekeeper and validation rule governing this cell's
  /// integrity and security.
  ///
  /// This property returns the [TestCell] instance associated with the cell's
  /// configuration. It serves as the authoritative **Security Policy** for the
  /// node, determining which signals, commands, or structural transitions are
  /// permitted based on the current execution environment.
  ///
  /// ### When to use
  /// Rarely needed in application code – the framework uses this internally
  /// to validate pulses and commands. You might inspect it for debugging or
  /// for custom deputy creation.
  ///
  /// ### How it works
  /// This is the cell's own validation rule. A deputy's rule is layered on
  /// top of this, but you can access the principal's rule via this getter.
  ///
  /// ### Returns:
  ///   The [TestCell] validator currently governing this node's operational
  ///   boundaries.
  TestCell get validate;

  /// The operational [Context] defining the security tier, execution priority,
  /// and administrative authority of this [Cell].
  ///
  /// The [context] is a foundational architectural element that represents the
  /// "Identity" or "Scope" under which the cell performs its logic. It acts
  /// as a mandatory metadata layer that informs the [validate] rule and
  /// processing mechanisms about the provenance and permissions of
  /// any entity attempting to interact with the node.
  ///
  /// ### When to use
  /// You'll typically only read this when writing custom rules or when
  /// creating a deputy that needs a different authority tier. For most
  /// application code, the default [Context.system] is sufficient.
  ///
  /// ### How it works
  /// The context is immutable for the cell. If you need a different context,
  /// create a deputy with a new context (which shares the same state).
  ///
  /// ### Returns:
  /// The [Context] instance representing the authority tier and operational
  /// domain of this node.
  Context get context;

  /// A boolean indicator identifying whether this [Cell] acts as a **Processing Sink**
  /// within the reactive graph.
  ///
  /// In a reactive architecture, a **Terminal Node** is a component that possesses the
  /// internal logic to process and store state but lacks the propagation mechanisms
  /// required to broadcast its updates to downstream dependents.
  ///
  /// ### When to use
  /// This is mostly informational. Terminal nodes (e.g. [Cell.observe]) have
  /// no downstream observers, so they're lightweight and won't cause cascade
  /// effects.
  ///
  /// ### Returns:
  /// `true` if this cell is a terminal node with no outgoing notification
  /// capabilities; `false` if it is a transit node that broadcasts its
  /// state changes to observers.
  bool get isTerminal;

  /// Indicates whether this [Cell] has initiated its **Automatic Termination**
  /// sequence and is currently in the process of being neutralized.
  ///
  /// This property reflects the **Active Invalidation State** of a reactive
  /// node. A cell enters this state when its [EphemeralPolicy]—the
  /// component responsible for **Lifecycle Governance**—determines that an
  /// operational threshold (such as a Time-to-Live expiration or a signal
  /// hop limit) has been reached.
  ///
  /// ### When to use
  /// Check this before interacting with a cell to avoid acting on a dead
  /// node. Especially important in long‑running systems with ephemeral cells.
  ///
  /// ### Returns:
  /// `true` if the cell's governance policy has emitted its termination
  /// sequence; `false` if the cell is currently stable and operational.
  bool get isInvalidated;

  /// Indicates whether this [Cell] is currently subject to a **Management Policy**
  /// that oversees its operational boundaries, security constraints, and administrative metadata.
  ///
  /// This property determines if the node's behavior is mediated by a
  /// **Policy Enforcement Point (PEP)**—utilizing security mandates, taxonomic
  /// definitions, and architectural invariants—rather than operating as a
  /// purely autonomous reactive unit.
  ///
  /// ### When to use
  /// This is useful for diagnostic or conditional logic – you might treat
  /// governed cells differently in logging or monitoring.
  ///
  /// ### Returns:
  /// * `true`: If the cell is managed by a governance framework (Managed Node).
  /// * `false`: If the cell is autonomous or operates without an external
  ///   management policy (Unmanaged/Free Node).
  bool get isGoverned;

  /// Executes a **State Transition** or arbitrary logic via the **Command Pattern** gateway.
  ///
  /// [apply] serves as the primary enforcement mechanism for a [Cell], bridging the gap
  /// between compile-time governance and runtime **Integrity Gate** validation.
  ///
  /// ### When to use
  /// - **Somatic State Transitions**: When you need to perform direct mutations or
  ///   execute business logic that is whitelisted in [modifiable].
  /// - **Transaction Orchestration**: When performing multiple, related updates that
  ///   must succeed or fail as a single atomic unit using an [ApplyTransactionScope].
  /// - **Compensating Transactions**: Defining reversal logic ([compensate]) for
  ///   SAGA-like patterns or complex state recovery.
  /// - **Dynamic Command Injection**: Executing logic that is determined at runtime
  ///   but must still pass through the node's security perimeter.
  ///
  /// ### How it works
  /// 1. **Capability Scrutiny**: The method verifies if the provided [function] is
  ///    present in the [modifiable] manifest.
  /// 2. **Integrity Gate Validation**: The request triggers a **Reciprocal Handshake**
  ///    with the cell's [TestCell]. The intent is evaluated against the node's
  ///    security invariants and administrative mandates.
  /// 3. **Causal Anchor**: A new internal stimulus is synthesized, carrying the
  ///    **Causal Provenance** (trace ID, timestamp, and operational context).
  /// 4. **Execution & Propagation**: If authorized, the function is executed within
  ///    the requested [tx] scope. The result is then broadcast through the
  ///    **Egress Gateway** to all downstream receptors.
  /// 5. **Compensate Registration**: If a [compensate] function is provided, it is
  ///    registered to be invoked if the transaction fails or requires rollback.
  ///
  /// ### Non‑obvious
  /// - **Short-Circuit Rejection**: If the **Integrity Gate** rejects the action,
  ///   the method returns `null` immediately without triggering any reactive waves.
  /// - **Transaction Isolation**: Operations within an [ApplyTransactionScope] prevent
  ///   "Glitch" states by ensuring downstream observers only see the final, committed transition.
  /// - **Flyweight Strategy**: The framework utilizes Record-based storage for
  ///   command metadata to minimize heap pressure during high-frequency mutations.
  /// - **Causal Lineage**: Even failed attempts are recorded in the system audit
  ///   log (if enabled), preserving the trace of the rejected stimulus.
  ///
  /// ```dart
  /// // Define a whitelisted mutation
  /// void increment(int amount) => value += amount;
  ///
  /// // Execute via the Command Pattern gateway
  /// final result = myCell.apply(
  ///   increment,
  ///   positionalArguments: [5],
  ///   compensate: (int amount) => value -= amount,
  /// );
  ///
  /// if (result == null) {
  ///   print('Action rejected by Integrity Gate');
  /// }
  /// ```
  ///
  /// ### Parameters:
  /// * [function]: **The Command Anchor.** A reference to the whitelisted function
  ///   to be executed.
  /// * [positionalArguments]: Optional arguments passed to the function by index.
  /// * [namedArguments]: Optional arguments passed to the function by [Symbol] keys.
  /// * [tx]: **The Transaction Scope.** An optional handle to group multiple
  ///   operations into an atomic wave.
  /// * [compensate]: **The Reversal Logic.** A function executed if the transaction
  ///   needs to be rolled back.
  /// * [compensatePositional]: Arguments for the compensation function.
  /// * [compensateNamed]: Named arguments for the compensation function.
  /// * [compensateCell]: An optional target cell for the compensation logic.
  ///
  /// ### Returns:
  /// The result of the executed [function] if authorized and validated; otherwise `null`.
  ///
  /// ### See Also:
  /// * [modifiable]: The capability manifest defining authorized actions.
  /// * [TestCell]: The **Integrity Gate** implementation.
  /// * [ApplyTransactionScope]: The coordinator for atomic multi-step updates.
  /// - **Example**: See `example/atomic_multi_update.dart` for a
  ///   walkthrough of bank transfer logic and multi-node consistency.
  dynamic apply(Function function, {List? positionalArguments, Map<Symbol, dynamic>? namedArguments,
    ApplyTransactionScope? tx,
    Function? compensate,
    List? compensatePositional,
    Map<Symbol, dynamic>? compensateNamed,
    Cell? compensateCell,
  });

  /// Defines the exhaustive whitelist of functions and commands that are
  /// permitted to be executed on this node via the dynamic [apply] method.
  ///
  /// This getter is a foundational component of the framework's **Command
  /// Pattern** and **Action-Based Security** architecture. It acts as a
  /// reflective **Capability Manifest**, declaring which specific operations
  /// on this cell instance are exposed for external or dynamic manipulation.
  ///
  /// ### When to use
  /// Rarely in application code – this is used internally for the command
  /// pattern and by deputies to restrict operations.
  ///
  /// ### Returns:
  ///   An [Iterable] of [Function] references that are authorized for
  ///   dynamic invocation on this cell.
  Iterable<Function> get modifiable;

  /// Returns a read-only, reactive projection (Deputy) of this [Cell].
  ///
  /// This getter is a cornerstone of the framework's **Security and
  /// Encapsulation** architecture. It implements the **Deputy Pattern**,
  /// providing a mechanism to expose a cell's state and reactivity to
  /// downstream observers while strictly prohibiting the authority to
  /// emit state transitions or structural modifications.
  ///
  /// ### When to use
  /// Use this when you need to give read‑only access to a cell – e.g. to a
  /// UI widget, a logger, or an external plugin.
  ///
  /// ### How it works
  /// - Returns a deputy with `testRule = TestCell.readOnly` (blocks mutations).
  /// - The deputy shares the same state, lock, and synapses as the principal.
  ///
  /// ### Non‑obvious
  /// - The deputy's `apply` method is disabled (modifiable is empty).
  /// - It is still reactive – changes to the principal are reflected.
  ///
  /// ### Example: Read-Only UI View
  /// ```dart
  /// final dataCell = Cell.state<int>(value: 42);
  /// final readOnly = dataCell.unmodifiable;
  /// MyWidget(data: readOnly);
  /// ```
  ///
  /// ### Returns:
  ///   A [Cell] instance representing a read-only projection of the current
  ///   node, effectively disabling all mutating operations.
  Cell get unmodifiable;

  /// Provides a high-level, asynchronous interface for interacting with this
  /// [Cell] node.
  ///
  /// This getter returns a [ModifiableAsync] wrapper, which serves as the
  /// primary architectural bridge between the synchronous reactive graph and
  /// Dart's asynchronous execution model ([Future]s and [Stream]s).
  ///
  /// ### When to use
  /// Use this when you need to perform a command or read state asynchronously,
  /// especially from UI event handlers or background tasks.
  ///
  /// ### How it works
  /// - All operations are scheduled through the cell's lock.
  /// - The result is wrapped in a [Future].
  ///
  /// ### Example:
  /// ```dart
  /// final cell = Cell();
  /// final result = await cell.async.apply((x) => x + 1, [5]);
  /// ```
  ///
  /// ### Returns:
  /// A [ModifiableAsync] wrapper specialized for this [Cell], providing
  /// a suite of asynchronous tools for command execution and state
  /// observation.
  ModifiableAsync<Cell> get async;

}

/// A specialized, interactive [Cell] that serves as a **Reactive Bridge** for
/// external stimulus injection and dynamic topology management.
///
/// While standard cells typically operate as passive residents within a
/// **Directed Acyclic Graph (DAG)**—reacting automatically to internal
/// state changes—an [OpenCell] provides the explicit interface required to
/// integrate external events (such as UI inputs, hardware interrupts, or
/// network packets) into the framework's internal reactive stream.
///
/// ### When to use
/// Use [Cell.open] to create an [OpenCell] when you need manual control over
/// signal injection or topology linking.
///
/// ### How it works
/// - `receptor(pulse)`: manually inject a pulse into the cell.
/// - `link(cell)`: attach a downstream observer.
/// - `unlink(cell)`: remove an observer.
///
/// ### Non‑obvious
/// Even though it's "open", it is still governed by its [testRule] – manual
/// pulses must pass validation.
///
/// See also:
/// * [Receptor]: The transformation engine used by the `receptor` method.
/// * [TestCell]: The validator that serves as the node's **Integrity Gate**.
/// * [Synapses]: The distribution registry managed by the `link` method.
/// {@category Core}
/// {@category Core 16 Operators}
abstract interface class OpenCell implements Cell {

  /// Creates a standard open cell.
  ///
  /// - [receptor]: The logic unit for processing incoming signals.
  /// - [bind]: An optional upstream cell to bind to (acting as a deputy).
  /// - [context]: The execution context (e.g., system vs user).
  /// - [testRule]: The validation rule determining permissions for this cell.
  ///   This allows restricting external access to open methods like [receptor] and [link].
  /// - [synapses]: The manager for downstream connections.
  factory OpenCell({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context context,
    Receptor receptor,
    TestCell testRule,
    Synapses synapses,

    bool forceLock
  }) = _OpenCell;

  factory OpenCell.governed({
    EphemeralPolicy? ephemeralPolicy,

    Cell? bind,
    Context context,
    Receptor receptor,
    TestCell testRule,
    Synapses synapses,

    bool forceLock
  }) = _OpenCell;

  /// Creates an [OpenCell] that encapsulates a specific functional transformation
  /// to be executed upon the ingestion of an external [Pulse].
  ///
  /// This factory is the primary architectural utility for building **Action-
  /// Oriented Reactive Nodes**. It allows developers to define a discrete
  /// piece of business logic (the [perform] function) that is emitted
  /// whenever the cell's public [emit] method is invoked.
  ///
  /// ### When to use
  /// Use this when you have an open cell that should execute a specific
  /// function on each manually injected pulse – e.g. a command handler.
  ///
  /// ### How it works
  /// - [source]: the principal cell that provides the state.
  /// - [perform]: the function to run on each pulse.
  /// - The resulting open cell is bound to `on` and will execute `perform`
  ///   on every `receptor` call.
  ///
  /// ### Parameters:
  /// - [source]: **Required**. The principal [Cell] that serves as the
  ///   operational target for the transformation.
  /// - [perform]: **Required**. The transformation logic that maps
  ///   input pulses to output state evolutions.
  /// - [user]: Optional metadata or configuration passed to the
  ///   [perform] callback.
  /// - [context]: The operational environment and authority tier.
  ///   Defaults to [Context.system].
  /// - [testRule]: The **Integrity Gate** (System Law) governing access.
  ///   Defaults to [TestCell.allowAll].
  /// - [synapses]: Configuration for managing downstream observers.
  ///
  /// ### Returns:
  /// A fully configured [OpenCell] capable of executing the [perform]
  /// logic upon pulse ingestion.
  static OpenCell perform(
      Cell source, Pulse? Function(Cell on, Pulse pulse, {dynamic user}) perform, {
    dynamic user,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled
  }) {
    return _OpenCell(
        bind: source,
        receptor: Receptor.pipeline(instruction: Instruction((Pulse pulse, {Cell? cell, dynamic user}) {
          return perform(cell!, pulse, user: user);
          }, user: user)),
        testRule: testRule,
        synapses: synapses
    );
  }

  /// Injects a [Pulse] into the cell for processing and distribution,
  /// supporting **Hybrid Convergence** (Sync/Async).
  ///
  /// This method is the public **Reactive Bridge** for emitting a cell's
  /// internal transformation logic from an external or imperative source.
  /// Unlike standard nodes that react to internal graph state, [emit]
  /// allows for "Signal Injection," effectively turning the cell into an
  /// **Actionable Endpoint**.
  ///
  /// ### When to use
  /// Call this manually to inject a pulse from outside the reactive graph.
  ///
  /// ### How it works
  /// The pulse is validated by [testRule] and then processed by the internal
  /// [Receptor]. The result is broadcast to all observers.
  ///
  /// ### Returns:
  /// A [FutureOr] containing the resulting [Pulse] if successful and
  /// authorized, or `null` if the signal was rejected by policy, filtered
  /// by logic, or if the causal chain was invalidated.
  FutureOr<Pulse?> emit(Pulse pulse);

  Future<void> ingest(Pulse pulse, {bool serializedCompletion = false}) async {
    final receptor = _nucleus.receptor;
    return await receptor.async.call(pulse as PulseBase, serializedCompletion: serializedCompletion);
  }

  /// Explicitly connects a downstream [Cell] to this node's egress stream,
  /// supporting **Hybrid Convergence** (Sync/Async).
  ///
  /// The [link] method provides a way to dynamically modify the topology of
  /// the **Digital Organism** at runtime. It grants public access to the node's
  /// [Synapses], allowing this cell to act as a **Signal Source** for the
  /// provided [cell].
  ///
  /// ### When to use
  /// Call this to attach a new observer to this open cell at runtime.
  ///
  /// ### How it works
  /// - The downstream cell is added to the internal observer registry.
  /// - The link is governed by [Synapses.link] – the request may be rejected.
  /// - Returns a function that, when called, removes the link.
  ///
  /// ### Returns:
  /// A [FutureOr] containing a `void Function()?` (the unlinker) which, when
  /// called, removes the connection. If the connection attempt was rejected
  /// by an **Integrity Gate**, it resolves to `null`.
  FutureOr<void Function()?> link(Cell cell);

  /// Synthesizes a specialized **Deputy Mandate** for this [OpenCell],
  /// providing a scoped and governed interface to the underlying reactive
  /// node while preserving its native **Open** capabilities.
  ///
  /// This method is the strongly-typed implementation of the **Proxy Pattern**
  /// tailored specifically for [OpenCell]. It produces a new instance that
  /// shares the physical state, identity, and transformation logic of the
  /// current cell (the **Principal**) but operates under a distinct behavioral
  /// and security profile defined by the provided [context] and [testRule].
  ///
  /// ### When to use
  /// Use this to create a restricted deputy of an open cell – e.g. one that
  /// can only link but not inject, or vice versa.
  ///
  /// ### How it works
  /// Similar to [Cell.deputy], but the resulting proxy is also an [OpenCell].
  ///
  /// ### Parameters:
  /// - [context]: The operational [DeputyContext] for this instance.
  ///   This determines the authority tier and **Mandate** for all actions
  ///   initiated through this specific handle.
  /// - [testRule]: The [TestCell] validator (**Integrity Gate**) that
  ///   governs this deputy's interaction surface.
  /// - [ephemeralPolicy]: An optional policy defining automatic reclamation
  ///   rules (TTL/Events) for this proxy.
  /// - [synapses]: The **Signal Manifest** for this deputy.
  ///   Defaults to [Synapses.enabled].
  ///
  /// ### Returns:
  /// A new [OpenCell] instance acting as a restricted, context-aware
  /// proxy of the current cell.
  @override
  OpenCell deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

  /// Provides the **Asynchronous Governance Interface** for this [OpenCell].
  ///
  /// This getter acts as the primary access point for **Asynchronous Signal
  /// Ingestion**. It returns an [OpenCellAsync] handle, which provides
  /// non-blocking overrides for the cell's reactive surface, ensuring that
  /// complex state transitions can be initiated without halting the
  /// **Host Environment**'s execution flow.
  ///
  /// ### When to use
  /// Use this when you need to call `receptor` asynchronously – e.g. from an
  /// async event handler.
  ///
  /// ### Returns:
  /// An [OpenCellAsync] instance that provides asynchronous,
  /// non-blocking access to this cell's reactive capabilities.
  @override
  OpenCellAsync get async;

}


