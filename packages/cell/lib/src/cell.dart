// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

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
/// complementary library providing 90+ instruction-layer `Flow` factories
/// for complex stream orchestration, advanced filtering, and
/// high-level data synchronization.
///
/// ### See Also:
/// - [Pulse] (the signal a cell processes).
/// - [ValueCell] (the concrete stateful type returned by [Cell.state]).
/// - **HowTo**: See `guide/HowTo-Start.md` for a comprehensive guide on
///   getting started with the Cell architecture and reactive patterns.
/// {@category Getting Started}
/// {@category Core}
/// {@category Core 16 Operators}
/// {@category Demo: aircraft}
/// {@category Transactions}
/// {@category Apply + Transactions}
///
/// ### AI Agent Guide
/// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
/// **When to use:** Read this page when a BRD sentence names an external fact, a retained value, or a side effect; then pick one static factory below.
/// **When NOT to use:**
///   {@macro ai-do-not-create-cell-as-policy}
///   {@macro ai-do-not-invent-cell-factories}
/// **Live signature:** `abstract interface class Cell` — pinned at `cell: 1.1.0`
/// **Do NOT confuse with:** `ValueCell` (the concrete stateful type returned by `Cell.state`).
/// **Guide:** `HowTo-Mitose-Cell.md` §2 "Cell.* factories this HowTo covers" (#cell-factories)
/// **Example:** `example/cell_example.dart`
/// **Cross-layer:** decision logic moves to `cell_flow`; collection history moves to `cell_tissue`.
/// **Minimal compilable example**
/// ```dart
/// final inGate = Cell.ingress<int>();
/// final seen = <int>[];
/// final o = Cell.observe(source: inGate.cell, effect: (Pulse p) => seen.add(p.payload as int));
/// inGate.emit(1);
/// o.stop();
/// print(seen); // [1]
/// ```
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
  /// explicit governance or security configuration.
  ///
  /// ### When to use
  /// Use this when you need a basic reactive node that processes pulses,
  /// transforms data, or acts as a relay in a larger topology. While most
  /// applications will use specialized factories like [Cell.state] or
  /// [Cell.ingress], this constructor remains the most flexible way to
  /// define custom stateless or stateful processors.
  ///
  /// ### How it works
  /// The factory wraps the provided parameters into an internal [Nucleus],
  /// which acts as the cell's "DNA":
  /// - **Ingress Link**: Via [bind], the cell establishes a dependency on an
  ///   upstream source, automatically subscribing to its pulses.
  /// - **Transformation Pipeline**: The [receptor] defines the business logic
  ///   invoked whenever a pulse arrives.
  /// - **Integrity Gate**: The [testRule] acts as a security membrane,
  ///   validating data before it reaches the receptor.
  /// - **Egress Network**: The [synapses] determine how the resulting update
  ///   is broadcast to downstream observers.
  ///
  /// ### Example: A Reactive Transformation Node
  /// ```dart
  /// // A cell that converts strings to uppercase
  /// final upperCell = Cell<String>(
  ///   bind: inputCell,
  ///   receptor: Receptor((cell, pulse, {user}) {
  ///     final input = pulse.payload as String;
  ///     return Pulse(input.toUpperCase());
  ///   }),
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [bind]: Optional upstream [Cell]. Establishes the primary **Ingress
  ///   Link** for automated signal flow.
  /// * [receptor]: The **Transformation Pipeline** defining how the cell
  ///   synthesizes incoming [Pulse] data. Defaults to [Receptor.passThrough].
  /// * [testRule]: The **Integrity Gate** validator used to authorize and
  ///   sanitize state changes. Defaults to [TestCell.allowAll].
  /// * [synapses]: Configuration for the **Signal Distribution Network**
  ///   (Egress). Defaults to [Synapses.enabled].
  ///
  /// ### Returns:
  /// A live [Cell] instance integrated into the reactive ecosystem,
  /// ready to observe, transform, and broadcast signals.
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
  /// for nodes requiring strict security, resource management, and compliance.
  /// It allows for the creation of a dedicated security perimeter, ensuring
  /// that every state transition is validated against a formal
  /// **Capability-Based Access Control (CBAC)** manifest.
  ///
  /// ### When to use
  /// Use this constructor when building infrastructure or domain-critical
  /// nodes that require:
  /// - **Lifecycle Management**: Auto-neutralization via [EphemeralPolicy] (e.g., TTL).
  /// - **Authority Tiers**: Explicit [context] requirements to prevent
  ///   unauthorized signal leakage.
  /// - **Atomic Boundaries**: Dedicated synchronization [Lock]s to prevent
  ///   concurrency issues in high-frequency environments.
  ///
  /// For typical application state that does not require administrative
  /// oversight, prefer the simpler [Cell.state] or [Cell.ingress].
  ///
  /// ### How it works
  /// 1. **Mandatory Configuration**: Unlike the default factory, `governed`
  ///    requires an explicit [context]. This ensures every managed node has
  ///    a defined security posture and logical lineage from the start.
  /// 2. **Mutual Authorization Handshake**: Governed cells participate in a
  ///    handshake where both the incoming [Pulse] and the cell's [Receptor]
  ///    scrutinize each other's [Context]. If either side lacks the required
  ///    clearance, the pulse is neutralized.
  /// 3. **Policy Integration**: The [ephemeralPolicy] monitors the cell's
  ///    activity. If the policy's terminal condition is met, the cell
  ///    automatically sets [isInvalidated] to `true` and detaches itself
  ///    from the graph.
  ///
  /// ### What "governed" means
  /// A cell is governed when it hosts an [EphemeralPolicy] in its [Nucleus],
  /// which makes `isGoverned` report `true`. When [ephemeralPolicy] is
  /// omitted here, the cell can still become governed by **inheritance**: if
  /// it is [bind]ed to an upstream cell that is governed, `isGoverned` walks
  /// the bind chain and reports `true`, and `isInvalidated` mirrors the
  /// upstream cell ("the head owns the body"). A policy passed to this factory
  /// is hosted locally and therefore overrides any policy inherited from
  /// upstream.
  ///
  /// ### Synchronization & ForceLock
  /// When [forceLock] is `true`, the cell initializes a new [Lock]. This
  /// effectively creates a **Private Transaction Domain**. Operations within
  /// this cell are atomic and isolated from the rest of the graph's
  /// synchronization, which is critical for preventing deadlocks or race
  /// conditions in complex asynchronous flows.
  ///
  /// ### Parameters:
  /// * [ephemeralPolicy]: **Lifecycle Governance.** Defines the TTL or
  ///   invalidation triggers for the node. Defaults to null (infinite life).
  /// * [context]: **Administrative Metadata.** Defines the Authority Tier,
  ///   Clearance, and logical lineage of the node.
  /// * [bind]: **Ingress Link.** The primary upstream dependency for
  ///   automated signal flow.
  /// * [receptor]: **Transformation Pipeline.** The logic defining how the
  ///   cell synthesizes incoming stimuli.
  /// * [testRule]: **Integrity Gate.** The [TestCell] used to authorize
  ///   and sanitize state changes. Defaults to [TestCell.allowAll].
  /// * [synapses]: **Egress Network.** Configures how signals are
  ///   distributed to downstream observers.
  /// * [forceLock]: **Atomic Isolation.** If `true`, the cell gains a
  ///   dedicated, private synchronization domain.
  ///
  /// ### Returns:
  /// A fully managed [Cell] instance with a dedicated policy perimeter and
  /// explicit lifecycle configuration.
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** infrastructure nodes needing a TTL ([EphemeralPolicy]), explicit [Context], or a private lock.
  /// **When NOT to use:** ordinary application state — `Cell.state` / `Cell.ingress` cover it.
  /// **Live signature:** `Cell.governed({ephemeralPolicy, context, bind, receptor, testRule, synapses, forceLock})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell` (the ungoverned default factory).
  /// **Guide:** `guide/HowTo-EphemeralPolicy.md` (governance)
  /// **Example:** `example/open_cell_demo.dart`
  /// **Cross-layer:** policy clauses are still a `cell_flow` concern; governance here is lifecycle/authority, not business policy.
  /// **Minimal compilable example**
  /// ```dart
  /// final g = Cell.governed(context: Context.system);
  /// print(g.isGoverned); // true
  /// ```
  factory Cell.governed(
      {EphemeralPolicy? ephemeralPolicy,
      Context context,
      Cell? bind,
      Receptor receptor,
      TestCell testRule,
      Synapses synapses,
      bool forceLock}) = _Cell;

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
  /// (the [Lock]) defined within the nucleus. When a lock is present, the
  /// cell's mutating operations are serialized through it, so several
  /// cells sharing one lock form a single **Atomic Transaction Domain**.
  /// This is a re-entrancy and ordering guarantee inside one Dart
  /// isolate — it is not a cross-thread memory fence; there are no
  /// threads in the Dart runtime's shared-memory sense.
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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** infrastructure only — hydrate a cell from a persisted / cloned [Nucleus] blueprint.
  /// **When NOT to use:** application state — use `Cell.state` / `Cell.ingress` / `Cell.derive` first.
  /// **Live signature:** `Cell.fromNucleus(Nucleus nucleus)` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Nucleus.evolve` (builds the blueprint; this activates it).
  /// **Guide:** `guide/HowTo-Nucleus.md` (nucleus blueprints)
  /// **Example:** `example/open_cell_demo.dart`
  /// **Cross-layer:** `Flow.toHandle` builds a Receptor so application code never hand-rolls one.
  /// **Minimal compilable example**
  /// ```dart
  /// final blueprint = Nucleus(
  ///   receptor: Receptor((cell, pulse, {user}) {
  ///     final token = pulse.payload as String;
  ///     return Pulse(token.isNotEmpty ? 'Valid' : 'Invalid');
  ///   }),
  ///   testRule: TestCell((value, {host, arguments, user}) => value is String),
  /// );
  /// final authCell = Cell.fromNucleus(blueprint);
  /// print(authCell);
  /// ```
  factory Cell.fromNucleus(Nucleus nucleus) = _Cell.fromNucleus;

  /// The propagation step label used by `ReceptorBase._proceed`.
  ///
  /// The value is constant per cell (it only depends on the cell's context
  /// role), so it is computed once instead of calling [toString] for every
  /// pulse that visits the cell.
  String get _stepString;

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
  /// - **HowTo**: See `guide/HowTo-Start.md` for a guide on bridging
  ///   imperative and reactive code.
  /// {@category Core 16 Operators}
///
/// ### AI Agent Guide
/// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
/// **When to use:** A BRD says "capture X" (an external fact enters the system) — identity, class, quantity, location, tick bus, ACK.
/// **When NOT to use:**
///   {@macro ai-do-not-create-cell-as-policy}
/// **Live signature:** `Cell.ingress<I>({refine, ephemeralPolicy, source, context, receptor, testRule, synapses, forceLock})` — pinned at `cell: 1.1.0`
/// **Do NOT confuse with:** `Cell.state` (retained value, not stateless entry).
/// **Guide:** `HowTo-Mitose-Cell.md` §3.1 "Cell.ingress — how the desk enters the graph" (#cell-ingress)
/// **Example:** `example/ingress_demo.dart`
/// **Cross-layer:** moves to `cell_flow` if the BRD says "wait for silence" or "rate-limit".
/// **Minimal compilable example**
/// ```dart
/// final gate = Cell.ingress<int>(
///   testRule: TestCell((v, {arguments, host, user}) => v is int && v >= 0),
/// );
/// gate.emit(1);
/// gate.emit(-1); // rejected by the TestCell gate
/// print('ok');
/// ```
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
  /// 3. **Validation**: If a [testRule] is provided, the incoming pulse is
  ///    evaluated against the rule. If the rule rejects the stimulus, the
  ///    cycle terminates.
  /// 4. **Evolution**: If an [evolve] function is provided, it is invoked
  ///    synchronously. It compares the `host.value` (current state) with the
  ///    `input` pulse to decide the next state.
  /// 5. **Commitment**: If `evolve` returns a new [Pulse], the state is
  ///    updated and immediately broadcast via [Synapses].
  ///
  /// ### Example: Validated Counter
  /// ```dart
  /// final counter = Cell.state<int>(
  ///   initial: 0,
  ///   // Transformation logic
  ///   evolve: (host, input) => Pulse(host.value + (input.payload as int)),
  ///   // Integrity Gate: Only allow increments less than 100
  ///   testRule: (host, input) => (input.payload as int) < 100,
  /// );
  ///
  /// counter.update(5);  // value becomes 5
  /// counter.update(150); // Rejected by testRule; value remains 5
  /// ```
  ///
  /// ### Parameters:
  /// * [initial]: The **Initial Seed.** The value assigned to the cell at
  ///   creation.
  /// * [evolve]: **Optional.** The **Transformation Pipeline** logic. It
  ///   determines how the incoming `input` maps to the final committed
  ///   state based on the current `host.value`.
  /// * [testRule]: **Integrity Gate.** A safety check that must approve
  ///   every incoming stimulus before it reaches the transformation logic.
  ///   Useful for enforcing domain invariants and mocking test scenarios.
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
  /// - **HowTo**: See `guide/HowTo-Start.md` for a comprehensive guide on
  ///   state management and reactive patterns.
  /// {@category Core 16 Operators}
///
/// ### AI Agent Guide
/// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
/// **When to use:** A BRD says "retain X" and the WalkThrough named **no** Tissue book; a setting read at any time (not a governed reserve).
/// **When NOT to use:**
///   {@macro ai-do-not-create-cell-to-hold-a-collection}
/// **Live signature:** `Cell.state<V>({initial, evolve, testRule})` — pinned at `cell: 1.1.0`
/// **Do NOT confuse with:** `Cell.ingress` (stateless entry) and `TissueValue` (governed reserve book in `cell_tissue`).
/// **Guide:** `HowTo-Mitose-Cell.md` §2 "Cell.* factories this HowTo covers" (#cell-factories)
/// **Example:** `example/state_demo.dart`
/// **Cross-layer:** prefer `TissueValue<V>` from `cell_tissue` when the WalkThrough named a reserve / pool book.
/// **Minimal compilable example**
/// ```dart
/// final counter = Cell.state<int>(initial: 0);
/// counter.update(5);
/// print(counter.cell.value); // 5
/// ```
  static StateHandle<V> state<V>({
    V? initial,
    Pulse<V>? Function(ValueCell<V> host, Pulse input)? evolve,
    TestCell testRule = TestCell.allowAll,
  }) {
    return ValueCell.create<V>(
      ValueNucleus<V>(
        transform: evolve != null
            ? (host, input, {user}) => evolve(host, input)
            : null,
        testRule: testRule,
      ),
      initial: initial,
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
///
/// ### AI Agent Guide
/// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
/// **When to use:** A pulse has already been *decided* and a book / side effect must move — the **only** Flow → Tissue glue in a Mitose Demo.
/// **When NOT to use:**
///   {@macro ai-do-not-observe-to-decide}
/// **Live signature:** `Cell.observe<P extends Pulse>({required Cell source, required void Function(P) effect, bool initiallyStarted = true})` — pinned at `cell: 1.1.0`
/// **Do NOT confuse with:** `Cell.ingress` (entry into the graph, not exit from it).
/// **Guide:** `HowTo-Mitose-Cell.md` §3.2 "Cell.observe — the only Flow → Tissue glue" (#cell-observe)
/// **Example:** `example/observe_demo.dart`
/// **Cross-layer:** the decision itself lives in a `cell_flow` instruction; the books live in `cell_tissue`.
/// **Minimal compilable example**
/// ```dart
/// final events = Cell.ingress<String>();
/// final o = Cell.observe(
///   source: events.cell,
///   effect: (Pulse p) => print('got ${p.payload}'),
/// );
/// events.emit('x');
/// o.stop();
/// ```
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

  /// Synthesizes a new [Cell] that acts as a **Reactive Projection** (or View)
  /// of an existing source cell.
  ///
  /// This factory implements the **Derivation Pattern**, which is the primary
  /// mechanism for creating functional data pipelines within the reactive graph.
  /// Unlike a standard [Cell], a derived cell does not hold independent state;
  /// its existence is purely defined by the transformation of stimuli arriving
  /// from its [source].
  ///
  /// ### Architectural Significance: The Transformation Valve
  /// A critical feature of this implementation is the support for **Nullable
  /// Projections**. By allowing the [project] function to return `null`, the
  /// framework enables an implicit **Valve Pattern**:
  /// - **Transformation**: Converting data from type [I] to type [O].
  /// - **Suppression**: If the projection returns `null`, the incoming signal
  ///   is neutralized. No state update occurs, and no downstream notifications
  ///   are dispatched.
  ///
  /// ### When to use
  /// - **Computed Properties**: Creating a view of a model (e.g., deriving a
  ///   `fullName` cell from a `user` cell).
  /// - **Reactive Filtering**: Suppressing updates that do not meet specific
  ///   business criteria (e.g., only propagating pulses where `amount > 0`).
  /// - **Type Adaptation**: Bridging two disparate domains by converting
  ///   low-level signals into high-level domain pulses.
  ///
  /// ### How it works
  /// 1. **Ingress Binding**: The new cell is automatically bound to the [source].
  /// 2. **Execution Gate**: When the [source] emits an [I] pulse, the [project]
  ///    logic is invoked within the cell's transformation pipeline.
  /// 3. **Null Handling**: If [project] returns `null`, the pipeline terminates
  ///    immediately. If it returns a pulse of type [O], the signal continues
  ///    its lineage to downstream observers.
  ///
  /// ### Example: Transforming and Filtering
  /// ```dart
  /// // Derives a count, but only pulses if the text is not empty
  /// final countCell = Cell.derive<StringPulse, IntPulse>(
  ///   source: textInputCell,
  ///   project: (input) {
  ///     if (input.payload.isEmpty) return null; // Valve: Signal neutralized
  ///     return Pulse(input.payload.length);    // Transformation
  ///   },
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [source]: The upstream [Cell] providing the raw signal.
  /// * [project]: The **Projection Logic.** A pure function that maps the
  ///   input pulse to an output pulse. Return `null` to suppress the signal.
  ///
  /// ### Returns:
  /// A new [Cell] instance representing the reactive projection of the [source].
  /// {@category Core 16 Operators}
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** A BRD says "show X derived from Y" — pure projection, no policy branches.
  /// **When NOT to use:** policy clauses (that is a `cell_flow` instruction); retained storage (that is `Cell.state`).
  /// **Live signature:** `Cell.derive<I extends Pulse, O extends Pulse>({required Cell source, required O? Function(I) project})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.synthesis` (fan-in from many sources, not 1-to-1).
  /// **Guide:** `HowTo-Mitose-Cell.md` §2 "Cell.* factories this HowTo covers" (#cell-factories)
  /// **Example:** `example/derive_demo.dart`
  /// **Cross-layer:** a projection of a rich `*Decision` onto a seam enum is `MapValue` in `cell_flow`.
  /// **Minimal compilable example**
  /// ```dart
  /// final src = Cell.ingress<int>();
  /// final dbl = Cell.derive<Pulse<int>, Pulse<int>>(
  ///   source: src.cell,
  ///   project: (p) => Pulse<int>((p.payload ?? 0) * 2),
  /// );
  /// final o = Cell.observe(source: dbl, effect: (Pulse p) => print(p.payload));
  /// src.emit(21);
  /// o.stop();
  /// ```
  static Cell derive<I extends Pulse, O extends Pulse>({
    required Cell source,
    required O? Function(I input) project,
  }) {
    // Implementation links the receptor to the projection logic
    return Cell(
      bind: source,
      receptor: Receptor((cell, pulse, {user}) {
        try {
          return project(pulse as I);
        } catch (e) {
          // Internal integrity check for type mismatch
          return null;
        }
      }),
    );
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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** One bus with many pulse types routed by `Pulse.type` (pattern / prefix / multicast).
  /// **When NOT to use:** v1 product lanes — two `Cell.ingress` lanes are simpler; do not replace a policy instruction.
  /// **Live signature:** `Cell.hub({spokes, governedSpokes, registrations, routing, multicast, fallback, distribution, relay, source})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.ingress` (single-path entry, no routing).
  /// **Guide:** `HowTo-Mitose-Cell.md` §2 "Cell.* factories this HowTo covers" (#cell-factories)
  /// **Example:** `example/hub_demo.dart`
  /// **Cross-layer:** the routed decision still belongs to `cell_flow`.
  /// **Minimal compilable example**
  /// ```dart
  /// final hub = Cell.hub(spokes: {
  ///   'echo': (cell, pulse, {user}) => Pulse('echo:${pulse.payload}'),
  /// });
  /// print(hub.root);
  /// ```
  static HubHandle hub({
    Map<String, Pulse? Function(Cell cell, Pulse pulse, {dynamic user})>?
        spokes,
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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** A BRD says "no name on the extract" — redact PII before a log / UI cell, or omit the field at the source.
  /// **When NOT to use:** as a substitute for never writing PII into Tissue rows; sanitize the *view*, keep the book clean.
  /// **Live signature:** `Cell.sanitized<P extends Pulse>(Cell source, {required P Function(P) redact, Sensitivity minSensitivity = Sensitivity.confidential})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.derive` (projection without the sensitivity gate).
  /// **Guide:** `HowTo-Mitose-Cell.md` §2 "Cell.* factories this HowTo covers" (#cell-factories)
  /// **Example:** `example/sanitized_demo.dart`
  /// **Cross-layer:** GDPR row shapes also belong to `cell_tissue` TestTissue rules.
  /// **Minimal compilable example**
  /// ```dart
  /// final src = Cell.ingress<int>();
  /// final clean = Cell.sanitized<Pulse<int>>(
  ///   src.cell,
  ///   redact: (p) => Pulse(p.payload, type: 'redacted'),
  /// );
  /// final o = Cell.observe(source: clean, effect: (Pulse p) => print(p.type));
  /// src.emit(42);
  /// o.stop();
  /// ```
  static Cell sanitized<P extends Pulse>(
    Cell source, {
    required P Function(P pulse) redact,
    Sensitivity minSensitivity = Sensitivity.confidential,
  }) {
    final receptor = _Receptor(reaction: (pulse, cell, {user}) {
      final p = pulse as P;
      // Fail closed: a privacy primitive must not let unclassified data
      // through. A pulse without sensitivity metadata (e.g. a plain
      // ingress pulse with PulseContext.system) is redacted, not passed.
      final sensitivity = p.context.sensitivity;
      final mustRedact =
          sensitivity == null || sensitivity.index >= minSensitivity.index;
      return mustRedact ? redact(p) : p;
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
  /// **Notification model:** writes are validated first, then applied
  /// sequentially while the participants' locks are held. A failure during
  /// the apply phase restores the prior values of the cells already written
  /// by this commit before the rollback is reported. Observers may still
  /// see the intermediate states of a multi-cell commit as each write lands;
  /// the commit's own `onCommit`/`onRollback` events fire exactly once,
  /// after the whole batch has settled.
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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** Coordinating multiple `ValueCell`s atomically (money, forms) **outside** a Mitose Demo.
  /// **When NOT to use:**
  ///   {@macro ai-do-not-use-cell-transaction-for-tissue}
  /// **Live signature:** `Cell.transaction([TransactionOptions options = const TransactionOptions()])` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.txApply` (the Mitose commit; participants are Tissue books).
  /// **Guide:** `HowTo-Mitose-Cell.md` §3.3 "Cell.transaction — not the Mitose commit" (#cell-transaction)
  /// **Example:** `example/transaction_demo.dart`
  /// **Cross-layer:** in a Mitose Demo, record it as deferred: `transaction deferred txApply on Tissue`.
  /// **Minimal compilable example**
  /// ```dart
  /// final a = Cell.state<int>(initial: 1);
  /// final b = Cell.state<int>(initial: 10);
  /// final tx = Cell.transaction();
  /// await tx.begin([a.cell, b.cell]);
  /// tx.update(a.cell, 2);
  /// tx.update(b.cell, 20);
  /// await tx.commit();
  /// print('${a.cell.value},${b.cell.value}'); // 2,20
  /// ```
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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** The BRD says two retained facts move together or not at all, or an external act can fail after a local write — participants are **Tissue books**, with `apply` + `compensate`.
  /// **When NOT to use:** one book with no undo (an ordinary Tissue write from `Cell.observe`); never wrap `riskOf` (policy is pure).
  /// **Live signature:** `Cell.txApply([TxApplyOptions options = const TxApplyOptions()])` → `ApplyTransactionScope` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.transaction` (coordinates `ValueCell`, not Tissue).
  /// **Guide:** `HowTo-Mitose-Cell.md` §3.4 "Cell.txApply — the only atomic commit, on Tissue" (#cell-txapply)
  /// **Example:** `example/atomic_multi_update.dart`
  /// **Cross-layer:** the books written inside the commands are `cell_tissue` collections.
  /// **Minimal compilable example**
  /// ```dart
  /// final counter = Cell.state<int>(initial: 0);
  /// final tx = Cell.txApply();
  /// await tx.execute(participants: [counter.cell], body: (scope) {
  ///   counter.update(5); // staged — committed when execute completes
  /// });
  /// print(counter.cell.value);
  /// ```
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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** Late-bind a device / module after boot, or manually manage link/unlink topology.
  /// **When NOT to use:** standard external facts — use `Cell.ingress`; rare in v1 Demos.
  /// **Live signature:** `Cell.open({ephemeralPolicy, context, source, receptor, testRule, synapses, forceLock})` → `OpenCell` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.ingress` (fixed single-path entry).
  /// **Guide:** `HowTo-Mitose-Cell.md` §2 "Cell.* factories this HowTo covers" (#cell-factories)
  /// **Example:** `example/open_cell_demo.dart`
  /// **Cross-layer:** dynamic routing decisions remain `cell_flow` concerns.
  /// **Minimal compilable example**
  /// ```dart
  /// final o = Cell.open();
  /// o.emit(Pulse('hello'));
  /// ```
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
  /// > **Diamond-dependency limitation.** The propagation engine visits
  /// > each cell at most once per pulse wave (`Pulse` cycle checking). In a
  /// > diamond (`A → B → D` and `A → C → D`) the second arrival at `D`
  /// > within the same wave is treated as a cycle and dropped, so `D` is
  /// > computed from the first arrival only — possibly with a stale value
  /// > of the other input. If the last arrival must win, aggregate in a
  /// > single combiner cell fed through one path (e.g. a `Cell.hub` or a
  /// > hand-rolled receptor cell) instead of a diamond-shaped fan-in.
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
  /// - **HowTo**: See `guide/HowTo-Start.md` for patterns on managing
  ///   complex information convergence.
  /// {@category Core 16 Operators}
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** "one screen / one status from many feeds" — aggregate current values whenever any source pulses.
  /// **When NOT to use:** a policy decision on the merged tick; and never use it *and* a custom instruction on the same tick without saying which decides.
  /// **Live signature:** `Cell.synthesis<P extends Pulse>(Iterable<Cell> sources, {required P? Function(Iterable<Cell> cells, Pulse emit) aggregator})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.derive` (single-source projection).
  /// **Guide:** `HowTo-Mitose-Cell.md` §2 "Cell.* factories this HowTo covers" (#cell-factories)
  /// **Example:** `example/synthesis_demo.dart`
  /// **Cross-layer:** multi-source *decision* logic belongs to `cell_flow` Combine operators or a harness-assembled Tick.
  /// **Minimal compilable example**
  /// ```dart
  /// final a = Cell.state<int>(initial: 2);
  /// final b = Cell.state<int>(initial: 3);
  /// final sum = Cell.synthesis<Pulse<int>>([a.cell, b.cell], aggregator: (cells, emit) {
  ///   final total = cells.fold<int>(0, (acc, c) => acc + (((c as ValueCell).value as int?) ?? 0));
  ///   return Pulse<int>(total);
  /// });
  /// final o = Cell.observe(source: sum, effect: (Pulse p) => print(p.payload));
  /// a.update(4);
  /// b.update(5);
  /// o.stop();
  /// ```
  static Cell synthesis<P extends Pulse>(
    Iterable<Cell> sources, {
    required P? Function(Iterable<Cell> cells, Pulse emit) aggregator,
  }) {
    late final SynthesisCell cell;
    final receptor = _Receptor(
      reaction: (pulse, host, {user}) => aggregator(cell, pulse),
    );
    cell = SynthesisCell(sources, receptor: receptor);
    return cell;
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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** a pure predicate gate that passes or suppresses pulses before expensive downstream work.
  /// **When NOT to use:** named business policy (clause-ordered, latch, product filter) — that is a `cell_flow` instruction, not a Cell predicate.
  /// **Live signature:** `Cell.valve<P extends Pulse>(Cell source, bool Function(P pulse) gate, {Synapses synapses = Synapses.enabled})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.distinct` (history-based; valve is stateless per pulse).
  /// **Guide:** `guide/HowTo-16_Essential_Operators.md` (valve)
  /// **Example:** `example/valve_demo.dart`
  /// **Cross-layer:** the rich policy version is `Filter` / `FlowInstructionBase` in `cell_flow`.
  /// **Minimal compilable example**
  /// ```dart
  /// final src = Cell.ingress<int>();
  /// final gated = Cell.valve<Pulse<int>>(src.cell, (p) => (p.payload ?? 0) > 0);
  /// final o = Cell.observe(source: gated, effect: (Pulse p) => print(p.payload));
  /// src.emit(1);
  /// src.emit(-1); // blocked by the gate
  /// o.stop();
  /// ```
  static Cell valve<P extends Pulse>(Cell source, bool Function(P pulse) gate,
      {Synapses synapses = Synapses.enabled}) {
    final receptor = _Receptor(
        reaction: (pulse, cell, {user}) => gate(pulse as P) ? pulse : null);
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
  /// ### Parameters:
  /// * [source]: **The Ingress Source.** The upstream [Cell] to be monitored
  ///   for stability.
  /// * [duration]: **The Stability Window.** The period of silence required
  ///   before the signal is allowed to propagate.
  /// * [leading]: **Initial Feedback.** If `true`, the first pulse of a burst
  ///   is propagated immediately. Defaults to `false`.
  /// * [ephemeralPolicy]: Optional TTL / event-limit policy hosted on the
  ///   debounce cell. A pending timer is cancelled once the cell is invalidated.
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
  /// - **HowTo**: See `guide/HowTo-Start.md` for a comprehensive guide on
  ///   reactive patterns and scheduling.
  /// {@category Core 16 Operators}
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** wait for silence on a feed (belt chatter, search input, 15 s snapshots) — feed shaping **before** `publishTick`.
  /// **When NOT to use:** as the policy gate; Time operators shape feeds, they never *decide*. A "wait for silence" decision is still a `cell_flow` instruction concern.
  /// **Live signature:** `Cell.debounce(Cell source, Duration duration, {bool leading = false, EphemeralPolicy? ephemeralPolicy})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.throttle` (frequency limit; leading defaults true).
  /// **Guide:** `HowTo-Mitose-Flow.md` §3.6 "Time" (#flow-time)
  /// **Example:** `example/stability_search_demo.dart`
  /// **Cross-layer:** identical semantics available as `Flow.debounce` in `cell_flow`.
  /// **Minimal compilable example**
  /// ```dart
  /// final src = Cell.ingress<String>();
  /// final db = Cell.debounce(src.cell, const Duration(milliseconds: 50));
  /// final o = Cell.observe(source: db, effect: (Pulse p) => print(p.payload));
  /// src.emit('a');
  /// src.emit('b');
  /// await Future<void>.delayed(const Duration(milliseconds: 80));
  /// o.stop();
  /// ```
  static Cell debounce(
    Cell source,
    Duration duration, {
    bool leading = false,
    EphemeralPolicy? ephemeralPolicy,
  }) =>
      _debounce(
        source,
        duration,
        leading: leading,
        ephemeralPolicy: ephemeralPolicy,
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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** limit a feed to at most one pulse per duration (leading immediate, trailing optional) — feed shaping **before** `publishTick`.
  /// **When NOT to use:** as the policy gate; the decision belongs to the `cell_flow` instruction, and Time operators shape feeds, not decisions.
  /// **Live signature:** `Cell.throttle(Cell source, Duration duration, {bool leading = true, bool trailing = false})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.debounce` (waits for silence; leading defaults false).
  /// **Guide:** `HowTo-Mitose-Flow.md` §3.6 "Time" (#flow-time)
  /// **Example:** `example/throttle_demo.dart`
  /// **Cross-layer:** identical semantics available as `Flow.throttle` in `cell_flow`.
  /// **Minimal compilable example**
  /// ```dart
  /// final src = Cell.ingress<int>();
  /// final th = Cell.throttle(src.cell, const Duration(milliseconds: 50));
  /// final o = Cell.observe(source: th, effect: (Pulse p) => print(p.payload));
  /// src.emit(1);
  /// src.emit(2); // throttled
  /// await Future<void>.delayed(const Duration(milliseconds: 80));
  /// o.stop();
  /// ```
  static Cell throttle(
    Cell source,
    Duration duration, {
    bool leading = true,
    bool trailing = false,
  }) =>
      _throttle(source, duration, leading: leading, trailing: trailing);

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
  /// - **HowTo**: See `guide/HowTo-17_Essential_Operators.md` for best
  ///   practices on filtering and flow control.
  /// {@category Core 16 Operators}
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** skip *consecutive* equal payloads (heartbeats, no-change ticks) before downstream work.
  /// **When NOT to use:** a latch that an ACK must reset — `Cell.distinct` has no `reset()`, so use a custom `cell_flow` instruction; global dedupe is `cell_flow`'s `Distinct`.
  /// **Live signature:** `Cell.distinct(Cell source, {bool Function(dynamic previous, dynamic next)? equals})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Distinct` (Flow, global seen-set) and `DistinctUntilChanged` (Flow, consecutive only) — both in `cell_flow`.
  /// **Guide:** `HowTo-Mitose-Flow.md` §3.3 "Filter / take / skip" (#flow-filter-take-skip)
  /// **Example:** `example/distinct_demo.dart`
  /// **Cross-layer:** policy latching is a Flow instruction concern, not this factory.
  /// **Minimal compilable example**
  /// ```dart
  /// final src = Cell.ingress<int>();
  /// final d = Cell.distinct(src.cell);
  /// final seen = <int>[];
  /// final o = Cell.observe(source: d, effect: (Pulse p) => seen.add(p.payload as int));
  /// src.emit(1);
  /// src.emit(1); // suppressed
  /// src.emit(2);
  /// o.stop();
  /// print(seen); // [1, 2]
  /// ```
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
  /// ### See Also:
  /// - **Example**: See `example/async_map_demo.dart` for a complete
  ///   walkthrough of managing parallel fetches, latest-only search updates,
  ///   and ordered sequential background tasks..
  /// * [Cell.switchMap]: To switch to a different source cell entirely.
  /// * [Cell.fromFuture]: To bridge a single, one-time async result.
  /// {@category asyncMap}
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** a background `Future` per pulse with concurrency control (`concurrency`, `latestOnly`, `exhaust`).
  /// **When NOT to use:** source selection (mapper returns a `Cell`) — that is `Cell.switchMap`; and never inside the policy decision itself.
  /// **Live signature:** `Cell.asyncMap<S, T>(Cell source, Future<T> Function(S value) mapper, {int concurrency = 0, bool latestOnly = false, bool exhaust = false})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.switchMap` (dynamic source rebinding, mapper returns `Cell`).
  /// **Guide:** `HowTo-Mitose-Flow.md` §3.4 "Flatten (inner sequences)" (#flow-flatten)
  /// **Example:** `example/async_map_demo.dart`
  /// **Cross-layer:** the orchestration equivalents are `Flow.asyncMap` / `Flow.asyncMapLatest` / `Flow.asyncMapConcurrent` in `cell_flow`.
  /// **Minimal compilable example**
  /// ```dart
  /// final src = Cell.ingress<int>();
  /// final am = Cell.asyncMap<int, String>(src.cell, (v) async => 'v=$v');
  /// final o = Cell.observe(source: am, effect: (Pulse p) => print(p.payload));
  /// src.emit(3);
  /// await Future<void>.delayed(const Duration(milliseconds: 30));
  /// o.stop();
  /// ```
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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** bridge an existing Dart `Stream` (PLC belt, WebSocket, `Stream.periodic`) into the graph.
  /// **When NOT to use:** a single value — that is `Cell.fromFuture`; imperative callbacks — that is `Cell.ingress`.
  /// **Live signature:** `Cell.fromStream<T>(Stream<T> stream, {bool cancelOnError = false, EphemeralPolicy? ephemeralPolicy})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.fromFuture` (single value, not a sequence).
  /// **Guide:** `HowTo-Mitose-Flow.md` §3.1 "Create" (#flow-create)
  /// **Example:** `test/operator_from_stream_test.dart`
  /// **Cross-layer:** the orchestration equivalent is `Flow.fromStream` in `cell_flow`.
  /// **Minimal compilable example**
  /// ```dart
  /// final s = Cell.fromStream<int>(Stream.fromIterable([1, 2, 3]));
  /// final o = Cell.observe(source: s, effect: (Pulse p) => print(p.payload));
  /// await Future<void>.delayed(const Duration(milliseconds: 30));
  /// o.stop();
  /// ```
  static Cell fromStream<T>(
    Stream<T> stream, {
    bool cancelOnError = false,
    EphemeralPolicy? ephemeralPolicy,
  }) =>
      _fromStream<T>(
        stream,
        cancelOnError: cancelOnError,
        ephemeralPolicy: ephemeralPolicy,
      );

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
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** bridge a single `Future` result into the graph (one config load, one AODB lookup); emits at most once.
  /// **When NOT to use:** continuous sources — that is `Cell.fromStream`; imperative callbacks — that is `Cell.ingress`.
  /// **Live signature:** `Cell.fromFuture<T>(Future<T> future)` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.fromStream` (sequence, not a single value).
  /// **Guide:** `HowTo-Mitose-Flow.md` §3.1 "Create" (#flow-create)
  /// **Example:** `test/receptor_instruction_future_test.dart`
  /// **Cross-layer:** the orchestration equivalent is `Flow.fromFuture` in `cell_flow`.
  /// **Minimal compilable example**
  /// ```dart
  /// final f = Cell.fromFuture<int>(Future.value(7));
  /// final o = Cell.observe(source: f, effect: (Pulse p) => print(p.payload));
  /// await Future<void>.delayed(const Duration(milliseconds: 10));
  /// o.stop();
  /// ```
  static Cell fromFuture<T>(Future<T> future) => _fromFuture<T>(future);

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
  /// - **HowTo**: See `guide/HowTo-17_Essential_Operators.md` for best practices
  ///   on using switching and routing operators.
  /// {@category Core 16 Operators}
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** dynamic source selection — the mapper returns a `Cell` and the graph rebinds to it ("latest reservation / flight only").
  /// **When NOT to use:** background enrichment where the mapper returns a `Future` — that is `Cell.asyncMap`.
  /// **Live signature:** `Cell.switchMap<S, T>(Cell source, Cell Function(S value) mapper, {ephemeralPolicy, context, testRule, synapses, forceLock})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.asyncMap` (Future per pulse, not source rebinding).
  /// **Guide:** `HowTo-Mitose-Flow.md` §3.4 "Flatten (inner sequences)" (#flow-flatten)
  /// **Example:** `example/instruction_pipeline_walkthrough.dart`
  /// **Cross-layer:** the orchestration equivalent is `Flow.switchMap` / `Flow.asyncMapLatest` in `cell_flow`.
  /// **Minimal compilable example**
  /// ```dart
  /// final src = Cell.ingress<String>();
  /// final sm = Cell.switchMap<String, int>(
  ///   src.cell,
  ///   (v) => Cell.state<int>(initial: v.length).cell,
  /// );
  /// final o = Cell.observe(source: sm, effect: (Pulse p) => print(p.payload));
  /// src.emit('abc');
  /// await Future<void>.delayed(const Duration(milliseconds: 20));
  /// o.stop();
  /// ```
  static Cell switchMap<S, T>(
    Cell source,
    Cell Function(S value) mapper, {
    EphemeralPolicy? ephemeralPolicy,
    Context context = Context.system,
    TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
    bool forceLock = false,
  }) =>
      _switchMap(
        source,
        mapper,
        ephemeralPolicy: ephemeralPolicy,
        context: context,
        testRule: testRule,
        synapses: synapses,
        forceLock: forceLock,
      );

  /// Creates an **Attenuated Proxy** (Deputy) of this cell with specialized
  /// governance and restricted authority.
  ///
  /// A Deputy is a defensive proxy that shares the same underlying state and
  /// identity as its principal, but operates under a different [context] or
  /// [testRule]. It is the primary tool for implementing **Capability-Based
  /// Access Control (CBAC)** within the switching fabric.
  ///
  /// ### Causal Integrity & Lineage
  /// To maintain strict provenance, the framework enforces **Contextual Lineage**:
  /// - The new [context] must be a direct descendant of the current deputy's
  ///   context (`context.parent == this.context`).
  /// - The [DeputyContext.system] acts as a root authority, allowing
  ///   evolution into any specialized context.
  /// - **Integrity Gate**: Attempting to "jump" a deputy to an unrelated
  ///   context tree triggers an [AssertionError].
  ///
  /// ### When to use
  /// - **Privilege Attenuation**: Creating a read-only or restricted-write
  ///   view of a cell to pass to untrusted components.
  /// - **Contextual Isolation**: Scoping a cell's signals to a specific
  ///   operational tier (e.g., UI-only, Background-only).
  /// - **Lifecycle Decoupling**: Assigning a different [EphemeralPolicy] to
  ///   a specific handle without affecting the principal's persistence.
  ///
  /// ### How it works
  /// - **Shared State**: The deputy points at the same physical storage and
  ///   [Lock] as its principal. Changes to one are immediately visible to both.
  /// - **Additive Rules**: The [testRule] is layered *additively* on top of
  ///   the principal's own rules. A deputy can only narrow permissions, never
  ///   grant authority the principal doesn't already possess.
  /// - **Reciprocal Handshake**: The proxy initialization performs a
  ///   cryptographic or logical handshake to ensure the binding is authorized.
  ///
  /// ### Example: Creating a Scoped Read-Only View
  /// ```dart
  /// // 1. Evolve the context to a specialized scope
  /// final userContext = currentContext.evolve(reason: 'UI_Binding');
  ///
  /// // 2. Create the attenuated deputy
  /// final readOnlyView = await cell.deputy(
  ///   context: userContext,
  ///   testRule: TestCell.readOnly,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [context]: The [DeputyContext] defining the authority tier. Must follow
  ///   **Causal Lineage** from the current context.
  /// * [testRule]: Additional [TestCell] restrictions, layered on top of
  ///   existing rules. Defaults to [TestCell.allowAll].
  /// * [ephemeralPolicy]: Optional independent lifecycle governance for this
  ///   specific proxy handle.
  /// * [synapses]: Configuration for an independent observer registry,
  ///   allowing isolated signal distribution for this deputy.
  ///
  /// ### Returns:
  /// A [FutureOr] resolving to an attenuated [Cell] proxy.
  ///
  /// - **Proxy Synthesis**: Returns a new deputy instance that shares the
  ///   underlying state of the principal but enforces the specialized
  ///   governance defined by the parameters.
  /// - **Identity Preservation**: If the requested parameters (context,
  ///   rules, etc.) match the current configuration, the method returns
  ///   the current instance (`this`) to prevent redundant proxy wrapping
  ///   and ensure referential efficiency.
  /// - **Handshake Resolution**: Because the **Reciprocal Handshake**
  ///   and context evolution may involve asynchronous authorization, the
  ///   result is wrapped in a [FutureOr] to support both immediate
  ///   synthesis and deferred clearance.
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** capability attenuation — read-only or narrowed-write views of a Cell for untrusted callers (UI, auditors).
  /// **When NOT to use:** to widen permissions (a deputy can only narrow); use `.unmodifiable` for the fixed read-only case.
  /// **Live signature:** `FutureOr<Cell> deputy({DeputyContext context = DeputyContext.system, TestCell testRule = TestCell.allowAll, EphemeralPolicy? ephemeralPolicy, Synapses synapses = Synapses.enabled})` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.unmodifiable` (fixed read-only deputy).
  /// **Guide:** `guide/HowTo-DeputyContext.md` (deputies)
  /// **Example:** `example/cell_example.dart`
  /// **Cross-layer:** Tissue books expose the same pattern via `.deputy(testRule: …)`.
  /// **Minimal compilable example**
  /// ```dart
  /// final c = Cell.state<int>(initial: 1);
  /// final d = await c.cell.deputy(testRule: TestCell.readOnly);
  /// print(d);
  /// ```
  FutureOr<Cell> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  /// The authoritative **Integrity Gate** governing this node's structural
  /// boundaries and operational authority.
  ///
  /// In the biological metaphor, the [validate] rule (a [TestCell] instance)
  /// acts as the **Immune System** or **Cell Membrane**. It serves as the
  /// primary security perimeter, evaluating every incoming [Pulse] to ensure
  /// that only stimuli meeting the node's integrity constraints and
  /// administrative authority are permitted to evolve the state.
  ///
  /// ### Architectural Significance: The Integrity Gate
  /// In a forensic-grade reactive environment, every interaction—whether
  /// a direct value update or a complex command—is intercepted by
  /// this gate. This ensures that the reactive graph remains consistent
  /// and that the **Causal Lineage** of a state change is never broken.
  ///
  /// ### How it works
  /// The integrity gate employs a **Tiered Resolution Strategy**:
  /// 1. **Local Override**: It first checks for a [TestCell] defined
  ///    explicitly in this handle's local segment.
  /// 2. **Prototype Inheritance**: If not found locally, it searches up the
  ///    inheritance chain (the prototype lineage) to inherit the rule from
  ///    its parent node.
  /// 3. **Causal Binding**: If the resolved rule is the default
  ///    [TestCell.allowAll] and the node is bound to an upstream source,
  ///    it adopts the integrity gate of that source.
  /// 4. **Global Default**: If no rule is found in the lineage or
  ///    bindings, it defaults to [TestCell.allowAll].
  ///
  /// ### Returns:
  /// The [TestCell] validator representing the active security perimeter
  /// of this node.
  TestCell get validate;

  /// The operational [Context] defining the forensic identity, administrative
  /// authority, and causal lineage of this specific [Cell] handle.
  ///
  /// The [context] is a foundational architectural element that represents the
  /// **Identity** or **Provenance** under which the cell performs its logic. It
  /// acts as the primary metadata anchor for the [validate] rule, providing
  /// the necessary evidence to verify if an incoming [Pulse] possesses the
  /// required authority to trigger a state transition.
  ///
  /// ### Architectural Significance: The Forensic Anchor
  /// In a multi-package or monorepo environment, the context ensures
  /// **Causal Integrity**. It prevents unauthorized "cross-talk" between
  /// different layers of the application (e.g., a UI component attempting
  /// to trigger a low-level system-tier mutation) by validating the
  /// lineage of every stimulus.
  ///
  /// ### When to use
  /// - **Integrity Rules**: Within a [TestCell] gate to verify if the acting
  ///   authority matches the expected tier for a specific command.
  /// - **Forensic Auditing**: When logging state changes to identify which
  ///   subsystem or authority triggered the mutation.
  /// - **Deputy Evolution**: To use as a parent reference when calling
  ///   [Context.evolve] to create a more specialized or restricted scope.
  ///
  /// ### How it works
  /// The context employs a **Tiered Resolution Strategy** to determine the
  /// handle's identity:
  /// 1. **Local Override**: It first checks for a context defined explicitly
  ///    in this node's local segment.
  /// 2. **Prototype Inheritance**: If not found locally, it walks up the
  ///    principal chain to inherit a context from its prototype.
  /// 3. **Causal Binding**: If the resolved context is the default
  ///    [Context.system] and the node is bound to an upstream source, it
  ///    adopts the context of the bound cell.
  /// 4. **Global Default**: If no context is found in the lineage or
  ///    bindings, it defaults to [Context.system].
  ///
  /// ### Returns:
  /// The [Context] instance representing the forensic anchor and authority
  /// tier of this node.
  Context get context;

  /// A boolean indicator identifying whether this [Cell] acts as a
  /// **Processing Sink** within the reactive topology.
  ///
  /// In the Cell-Mitosis architecture, a **Terminal Node** is a specialized
  /// component that possesses the internal logic to process pulses and
  /// maintain state, but lacks the propagation mechanisms required to
  /// broadcast its updates to downstream dependents.
  ///
  /// ### Architectural Significance: The Reactive Sink
  /// Terminal nodes represent the leaf nodes of a reactive graph. Unlike
  /// standard transit nodes, terminal nodes do not maintain a registry of
  /// downstream observers, making them significantly more memory-efficient
  /// for high-frequency updates where only the final side-effect matters.
  ///
  /// ### When to use
  /// - **Observation & Side-Effects**: Identifying cells created via
  ///   `Cell.observe` or `Cell.sink`, which are intended to bridge the
  ///   reactive world into imperative systems (like logging or database I/O).
  /// - **Performance Tuning**: Detecting nodes that will never trigger
  ///   cascade updates, allowing for optimizations in batch processing or
  ///   atomic transactions.
  /// - **Topology Mapping**: Used by framework-level tools to visualize
  ///   the boundaries and "exit points" of a reactive circuit.
  ///
  /// ### How it works
  /// 1. **Synapse Absence**: A terminal node is initialized with
  ///    [Synapses.disabled], preventing it from establishing outgoing
  ///    connections or consuming resources for observer management.
  /// 2. **Pulse Absorption**: When a terminal node receives a [Pulse],
  ///    it updates its internal state and executes its [Instruction],
  ///    but the signal propagation terminates at this node.
  /// 3. **Memory Efficiency**: Since no observer links are created,
  ///    terminal nodes are easier for the garbage collector to reclaim
  ///    once their parent handle is released.
  ///
  /// ### Returns:
  /// * `true`: If this cell is a terminal sink with no outgoing
  ///   notification capabilities.
  /// * `false`: If this is a transit node that broadcasts state
  ///   changes to downstream observers.
  bool get isTerminal;

  /// Indicates whether this [Cell] has initiated its **Automatic Termination**
  /// sequence and is currently in the process of being neutralized.
  ///
  /// This property reflects the **Active Invalidation State** of a reactive
  /// node. A cell enters this state when its [EphemeralPolicy]—the
  /// component responsible for **Lifecycle Governance**—determines that an
  /// operational threshold has been reached.
  ///
  /// ### Architectural Significance: The Neutralization Phase
  /// In the Cell-Mitosis lifecycle, invalidation is the transitionary phase
  /// between **Active Vitality** and **Garbage Collection**.
  /// - **Trigger Mechanisms**: A node may be invalidated due to a
  ///   Time-to-Live (TTL) expiration, a signal "hop limit" (Causal Lineage
  ///   depth), or an explicit call to the `neutralize()` command.
  /// - **Operational Guard**: Once `isInvalidated` is `true`, the node's
  ///   **Integrity Gate** will begin rejecting all incoming [Pulse]s
  ///   and [apply] commands to prevent state corruption.
  ///
  /// ### When to use
  /// - **Stale Data Prevention**: Check this before interacting with a cell
  ///   in long-running asynchronous operations to ensure you aren't acting
  ///   on a node that is no longer part of the active reactive graph.
  /// - **Resource Cleanup**: Use this as a signal to detach listeners or
  ///   dispose of UI controllers bound to this specific node.
  /// - **Dynamic Topology**: Framework-level logic uses this to prune dead
  ///   branches from the reactive tree during **Switching Fabric** maintenance.
  ///
  /// ### How it works
  /// 1. **Policy Egress**: The [EphemeralPolicy] attached to the cell
  ///    monitors usage patterns and environmental signals.
  /// 2. **Signal Propagation**: When the policy triggers, the cell emits
  ///    a final "Neutralization Pulse" to notify downstream observers
  ///    that it is shutting down.
  /// 3. **State Freezing**: While the cell may still hold its last value
  ///    in memory, `isInvalidated` serves as a semantic lock, preventing
  ///    further state transitions.
  ///
  /// ### Returns:
  /// * `true`: If the cell's governance policy has emitted its termination
  ///   sequence and the node is no longer operational.
  /// * `false`: If the cell is currently stable, healthy, and participating
  ///   in the reactive topology.
  bool get isInvalidated;

  /// Indicates whether this node is subject to active **Administrative Oversight**
  /// or specialized **Lifecycle Governance**.
  ///
  /// In the forensic architecture of the framework, a node is considered "Governed"
  /// if it departs from the default, passive system state by carrying either an explicit
  /// operational mandate ([Context]) or a defined survival policy ([EphemeralPolicy]).
  ///
  /// ### When to use
  /// - **Resource Management**: To identify nodes that require active teardown or
  ///   monitoring by a lifecycle manager or garbage collector.
  /// - **Security Auditing**: To distinguish between standard system-tier nodes and
  ///   nodes operating under elevated or specialized administrative boundaries.
  /// - **Forensic Diagnostics**: To isolate nodes in a complex graph that possess
  ///   transient lineage or non-standard authority vectors.
  ///
  /// ### How it works
  /// Governance is determined by the presence of an [EphemeralPolicy],
  /// resolved in two tiers:
  /// 1. **Hosted policy**: if this node's [Nucleus] — or its `principal` chain,
  ///    for deputies — carries an [EphemeralPolicy], the node is immediately
  ///    governed. A hosted policy always wins.
  /// 2. **Upstream policy**: if no policy is hosted, the node checks its
  ///    upstream [Cell.bind]. If the bind is governed, the node inherits that
  ///    state (**"the head owns the body"**), so a downstream projection of a
  ///    governed source also reports `true`.
  /// 3. **Default**: with neither a hosted nor an upstream policy, the node is
  ///    un-governed (`false`).
  ///
  /// ### Example: Inspecting Governance State
  /// ```dart
  /// final policy = EphemeralPolicy(
  ///   duration: Duration(minutes: 5),
  ///   onEvent: (object, {required cell, policy, arguments, user}) => (events: 0),
  ///   onInvalidate: (nucleus) => true,
  /// );
  ///
  /// final head = Cell.governed(ephemeralPolicy: policy, context: Context.system);
  /// final body = Cell(bind: head); // hosts no policy of its own
  ///
  /// print(head.isGoverned); // true (hosted policy)
  /// print(body.isGoverned); // true (inherited from the upstream bind)
  /// ```
  ///
  /// ### Returns:
  /// * `true`: If the cell is managed by a governance framework (**Managed Node**).
  /// * `false`: If the cell is autonomous or operates without an external
  ///   management policy (**Autonomous/Free Node**).
  ///
  /// ### See also:
  /// * [Context] – Establishes the authoritative identity driving the governance model.
  /// * [EphemeralPolicy] – Regulates transient survival constraints on governed nodes.
  bool get isGoverned;

  /// Submits an [ApplyCommand] to trigger a state change or an action within this cell.
  ///
  /// [apply] is the primary architectural gateway for every mutation in the framework.
  /// Instead of calling functions directly, you submit a "Nervous Signal" (a command)
  /// that the cell must vet, execute, and record in its history.
  ///
  /// In the framework's biological metaphor, this represents **Signal Transmission**.
  /// It sends a nervous impulse through the cell's governance layer to request a
  /// mutation in its underlying DNA (state).
  ///
  /// ### When to use
  /// - **State Mutations**: Use this whenever you need to update a cell's value
  ///   in a way that is traceable and safe.
  /// - **Governed Actions**: Use this for logic that requires "Integrity Gates"
  ///   (safety rules) to prevent invalid data transitions.
  /// - **Grouped Changes**: Use this when multiple actions must happen together
  ///   as a single "all-or-nothing" transaction.
  ///
  /// ### How it works
  /// 1. **Permission Check**: The cell verifies if its current state allows
  ///    mutations by checking the [modifiable] manifest.
  /// 2. **Integrity Gate**: The cell's safety rules ([TestCell.action]) inspect
  ///    the command and its data to ensure they are valid.
  /// 3. **Execution**: If authorized, the function is run. If a transaction scope
  ///    ([tx]) is provided, the change is "staged" in the ledger and waits for
  ///    the transaction to finish.
  /// 4. **Outcome**: The framework returns an [ApplyOutcome], which acts as
  ///    the official **Forensic Receipt** for the action.
  ///
  /// ### Parameters
  /// - **command**: The [ApplyCommand] record. This contains the function you
  ///   want to run, the data (arguments) it needs, and the optional "undo" logic.
  /// - **tx**: An optional [ApplyTransactionScope]. Provide this if you want the
  ///   command to be part of a larger transaction that succeeds or fails as a group.
  ///
  /// ### Non‑obvious behavior
  /// - **Causal Binding**: Every receipt contains a unique ID and timestamp. This
  ///   creates a permanent forensic trail, allowing you to trace any state
  ///   change back to the exact impulse that triggered it.
  /// - **Atomic Rollbacks**: If a command includes "compensation" logic, the
  ///   framework can use it to perform a **Genetic Undo**, restoring the
  ///   previous state if a complex transaction fails later.
  /// - **Authority Hierarchy**: Arguments passed directly to [apply] act as a
  ///   `local override`, taking precedence over inherited defaults.
  ///
  /// ### Technical Details
  /// - **Execution Context**: Returns a [FutureOr]. If the mutation is simple,
  ///   it returns the result immediately. If the mutation is asynchronous,
  ///   it returns a [Future].
  /// - **Memory Efficiency**: The command and receipt use "Flyweight" records
  ///   to minimize memory overhead, even when tracking thousands of signals.
  ///
  /// ### Example: Submitting a Governed Mutation
  /// ```dart
  /// // 1. Define the mutation logic (the "impulse")
  /// final updateProfile = (String name, {bool active = true}) {
  ///   return User(name: name, active: active);
  /// };
  ///
  /// // 2. Assemble the signal using the fluent builder (DSL)
  /// // This creates the "Nervous Signal" with a built-in "Genetic Undo"
  /// final outcome = await userCell.command(updateProfile)
  ///   .args(['Simon'])
  ///   .named({#active: true})
  ///   .undo(updateProfile, args: ['Previous Name'], named: {#active: false})
  ///   .run();
  ///
  /// // 3. Handle the Forensic Receipt using modern Dart pattern matching
  /// switch (outcome) {
  ///   case ApplyAccepted(result: final user, receipt: final r):
  ///     print('Mutation successful: ${user.name} (ID: ${r.id})');
  ///
  ///   case ApplyRejected(reason: final error):
  ///     print('Integrity Gate blocked mutation: $error');
  ///
  ///   case ApplyStaged(receipt: final r):
  ///     print('Signal queued in forensic ledger: ${r.id}');
  /// }
  /// ```
  ///
  /// ### See also:
  /// - **HowTo**: See `HowTo-Cell.apply.md` for a comprehensive guide on
  ///   getting started with the Cell architecture and reactive patterns.
  /// - [ApplyCommand] — The structural blueprint of a signal impulse.
  /// - [ApplyOutcome] — The sealed hierarchy of transition results.
  FutureOr<ApplyOutcome<R>> apply<R>(
    ApplyCommand command, {
    ApplyTransactionScope? tx,
  });

  /// Defines the exhaustive whitelist of functions and commands authorized for
  /// execution on this node via the dynamic [apply] method.
  ///
  /// This property is a foundational component of the framework's **Command
  /// Pattern** and **Action-Based Security** architecture. It acts as a
  /// reflective **Capability Manifest**, declaring which specific operations
  /// are exposed for external or dynamic manipulation on this [Cell] instance.
  ///
  /// ### Relationship with [Cell.unmodifiable]
  /// There is a direct, reciprocal relationship between these two members:
  /// - **[Cell.modifiable] (The Authority)**: Provides the set of "Keys" or
  ///   capabilities that allow a caller to trigger state transitions via
  ///   the [apply] gateway.
  /// - **[Cell.unmodifiable] (The Egress)**: Produces a [Cell] projection where
  ///   this [modifiable] list is **explicitly nullified**. While the deputy
  ///   retains the same state, it possesses zero capabilities from this
  ///   manifest, ensuring it remains read-only.
  ///
  /// ### When to use
  /// - **Internal Orchestration**: Used by the [apply] method to verify if a
  ///   requested command is within the cell's authorized perimeter.
  /// - **Security Auditing**: Checking the surface area of a reactive node to
  ///   determine what mutations are possible at runtime.
  /// - **Dynamic UI Generation**: Discovering available actions to
  ///   automatically render buttons or controls that map to whitelisted commands.
  ///
  /// ### How it works
  /// 1. **Capability Matching**: When [apply] is called with a function
  ///    reference, the cell checks if that reference exists within this [Iterable].
  /// 2. **Integrity Gate**: Even if a function is in this manifest, the
  ///    [TestCell] (Integrity Gate) may still reject the specific execution
  ///    context or payload.
  /// 3. **Deputy Restriction**: In "Deputy" nodes (created via [Cell.unmodifiable]),
  ///    this getter is hardcoded to return an empty collection, effectively
  ///    disabling the command pattern gateway.
  ///
  /// ### Returns:
  /// An [Iterable] of [Function] references that represent the authorized
  /// mutation surface of this node.
  Iterable<Function> get modifiable;

  /// Returns a read-only, reactive projection (Deputy) of this [Cell].
  ///
  /// This getter is a cornerstone of the framework's **Security and
  /// Encapsulation** architecture. It implements the **Deputy Pattern**,
  /// providing a mechanism to expose a cell's state and reactivity to
  /// downstream observers while strictly prohibiting the authority to
  /// emit state transitions or structural modifications.
  ///
  /// ### Relationship with [modifiable]
  /// There is a direct inverse relationship between these two members:
  /// - **[modifiable]**: Represents the **Capability Manifest**—the whitelist
  ///   of functions authorized to mutate the cell via [apply].
  /// - **[unmodifiable]**: Returns a read-only projection of this cell.
  ///   Mutations are rejected by the layered integrity gate, and direct
  ///   mutation paths (such as [ValueCell.value] assignment) are sealed.
  ///
  /// ### When to use
  /// Use this to follow the **Principle of Least Privilege**. Pass an
  /// `unmodifiable` handle to UI components, logging services, or external
  /// plugins that need to react to state changes but should never be allowed
  /// to trigger them.
  ///
  /// ### How it works
  /// 1. **Rule Layering**: The projection layers [TestCell.readOnly] on top
  ///    of the principal's rule through the `validate` seam, so every vetted
  ///    [apply] action is rejected while pulses (non-Function objects) still
  ///    propagate.
  /// 2. **State Sharing**: The projection shares the exact same underlying
  ///    state, lock, and transformation pipeline as the principal cell,
  ///    ensuring zero-latency reactivity without memory duplication.
  /// 3. **Capability Enforcement**: every `apply` — manifest member or not —
  ///    is vetted by the integrity gate (`validate.action`). [TestCell.readOnly]
  ///    rejects every Function action, so an unmodifiable projection cannot
  ///    be made to run code; the [modifiable] manifest remains a capability
  ///    declaration consumed by rules, not a bypass switch. Direct write
  ///    paths are sealed separately.
  ///
  /// ### Example: Encapsulating Domain Logic
  /// ```dart
  /// class UserAccount {
  ///   // The internal, private state that allows mutations
  ///   final Cell<int> _balance = Cell.state(value: 100);
  ///
  ///   // Expose only the unmodifiable deputy to the UI
  ///   Cell<int> get balance => _balance.unmodifiable;
  ///
  ///   void deposit(int amount) {
  ///     // Only the owner of the private _balance can call apply
  ///     _balance.apply((val) => val + amount);
  ///   }
  /// }
  /// ```
  ///
  /// ### Returns:
  /// A [Cell] instance representing a read-only projection of the current
  /// node.
  ///
  /// ### AI Agent Guide
  /// **Layer:** Cell — this is a graph node. Not an operator (Flow), not a book (Tissue).
  /// **When to use:** hand a UI / auditor a read-only view of a Cell; least-privilege egress.
  /// **When NOT to use:** as a copy — it is a live proxy sharing the principal's state.
  /// **Live signature:** `Cell get unmodifiable` — pinned at `cell: 1.1.0`
  /// **Do NOT confuse with:** `Cell.deputy` (parameterized attenuation; `unmodifiable` is the fixed read-only case).
  /// **Guide:** `guide/HowTo-DeputyContext.md` (deputies)
  /// **Example:** `example/cell_example.dart`
  /// **Cross-layer:** the Tissue equivalent is `.unmodifiable` on `TissueList` / `TissueMap` / `TissueSet` / `TissueQueue` / `TissueValue`.
  /// **Minimal compilable example**
  /// ```dart
  /// final c = Cell.state<int>(initial: 1);
  /// final ro = c.cell.unmodifiable;
  /// print(ro);
  /// ```
  Cell get unmodifiable;

  /// Provides a high-level, asynchronous interface for interacting with this
  /// [Cell] node.
  ///
  /// This getter returns a [ModifiableAsync] wrapper, which serves as the
  /// primary architectural bridge between the synchronous reactive graph and
  /// Dart's asynchronous execution model ([Future]s and [Stream]s).
  ///
  /// ### The Temporal Bridge
  /// While the core of a [Cell] is designed for synchronous, atomic
  /// transitions within the reactive topology, real-world applications
  /// frequently require non-blocking operations. The [async] handle allows
  /// for **Hybrid Convergence**, where imperative, time-delayed logic
  /// safely interacts with the cell's protected state.
  ///
  /// ### When to use
  /// - **UI Interaction**: Dispatching commands from event handlers (e.g.,
  ///   `onPressed`) without blocking the main isolate.
  /// - **Background Orchestration**: Executing business logic that involves
  ///   I/O or heavy computation while maintaining reactive integrity.
  /// - **Serialized Transitions**: When multiple mutations must be queued
  ///   and executed in order, ensuring no race conditions occur during
  ///   asynchronous gaps.
  ///
  /// ### How it works
  /// 1. **Lock Orchestration**: All operations performed via [async] (such
  ///    as `apply` or `read`) are automatically scheduled through the cell's
  ///    internal [Lock]. This guarantees atomicity even when calls originate
  ///    from different asynchronous contexts.
  /// 2. **Future Wrapping**: Standard methods like [apply] are mirrored here
  ///    but return a [Future], allowing the caller to `await` the result of
  ///    the reactive transition.
  /// 3. **Capability Preservation**: The [async] handle respects the
  ///    underlying node's [modifiable] manifest and [TestCell] rules. If
  ///    called on an [unmodifiable] deputy, the async mutation methods
  ///    will still respect the restricted capability policy.
  ///
  /// ### Example: Asynchronous Command Execution
  /// ```dart
  /// void onDepositPressed(int amount) async {
  ///   // The async handle allows awaiting the completion of the transition
  ///   final success = await userBalanceCell.async.apply(
  ///     (current) => current + amount
  ///   );
  ///
  ///   if (success != null) {
  ///     print('Deposit processed successfully.');
  ///   }
  /// }
  /// ```
  ///
  /// ### Returns:
  /// A [ModifiableAsync] wrapper specialized for this [Cell], providing
  /// a suite of asynchronous tools for command execution, state
  /// observation, and signal ingestion.
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
abstract interface class OpenCell implements Cell {
  /// Creates a standard open cell.
  ///
  /// - [receptor]: The logic unit for processing incoming signals.
  /// - [bind]: An optional upstream cell to bind to (acting as a deputy).
  /// - [context]: The execution context (e.g., system vs user).
  /// - [testRule]: The validation rule determining permissions for this cell.
  ///   This allows restricting external access to open methods like [receptor] and [link].
  /// - [synapses]: The manager for downstream connections.
  factory OpenCell(
      {EphemeralPolicy? ephemeralPolicy,
      Cell? bind,
      Context context,
      Receptor receptor,
      TestCell testRule,
      Synapses synapses,
      bool forceLock}) = _OpenCell;

  factory OpenCell.governed(
      {EphemeralPolicy? ephemeralPolicy,
      Cell? bind,
      Context context,
      Receptor receptor,
      TestCell testRule,
      Synapses synapses,
      bool forceLock}) = _OpenCell;

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
  static OpenCell perform(Cell source,
      Pulse? Function(Cell on, Pulse pulse, {dynamic user}) perform,
      {dynamic user,
      TestCell testRule = TestCell.allowAll,
      Synapses synapses = Synapses.enabled}) {
    return _OpenCell(
        bind: source,
        receptor: Receptor.pipeline(
            instruction: Instruction((Pulse pulse, {Cell? cell, dynamic user}) {
          return perform(cell!, pulse, user: user);
        }, user: user)),
        testRule: testRule,
        synapses: synapses);
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
    return await receptor.async
        .call(pulse as PulseBase, serializedCompletion: serializedCompletion);
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
  OpenCell deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestCell testRule = TestCell.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});

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
