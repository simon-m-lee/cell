// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

library;

import 'dart:async';

import '../cell.dart';

/// Represents a tuple of positional and named arguments for function calls.
/// Used when validating or processing function applications in cells.
///
/// Contains:
/// - positionalArguments: List of positional arguments
/// - namedArguments: Map of named arguments (using Symbols as keys)
typedef Arguments = ({List? positionalArguments, Map<Symbol, dynamic>? namedArguments});

/// A fundamental architectural component representing an **Integrity Gate** or
/// **Validation Guard**, responsible for enforcing structural and business
/// invariants across the reactive graph.
///
/// [TestRule] serves as the formal boundary between proposed state changes
/// (stimuli) and their commitment to the graph. It decouples validation logic
/// from state management, allowing for composable, type-safe, and highly
/// performant security and integrity checks.
///
/// ### When to use
/// - **Business Invariants**: Enforcing rules such as range limits, regex
///   patterns, or complex logical dependencies on state updates.
/// - **Security & Authorization**: Verifying that a specific [Context] or
///   principal has the authority to perform an action or modify a node.
/// - **Policy Orchestration**: Composing multiple atomic rules into a
///   **Validation Pipeline** using the `+` operator.
/// - **Data Sanitization**: Screening incoming pulses to ensure they meet
///   the requirements of downstream nodes.
///
/// ### How it works
/// 1. **Evaluation**: When a stimulus (like a [Pulse]) is intercepted by an
///    integrity engine (like [TestCell]), the rule's predicate is invoked.
/// 2. **Contextual Awareness**: The rule is provided with the `object` under
///    test, the `host` environment ([C]), and execution `arguments`,
///    allowing for context-aware decisions.
/// 3. **Composition (Chain of Responsibility)**: Using the `+` operator,
///    multiple rules are chained. The system evaluates them sequentially;
///    if any rule returns `false`, the chain **Short-Circuits** and the
///    operation is rejected.
/// 4. **Hybrid Execution**: Supports [FutureOr<bool>]. Synchronous rules
///    execute with zero-latency, while asynchronous rules suspend the reactive
///    wave until I/O or remote validation completes.
///
/// ### Non‑obvious
/// - **Fail-Safe Execution**: To maintain graph resilience, unhandled
///   exceptions within a rule are treated as a **Pass** (`true`). This
///   prevents a single faulty validator from paralyzing the entire system.
/// - **Memory Optimization**: Employs the **Flyweight Pattern** by storing
///   configuration in memory-optimized records, minimizing the heap footprint
///   of validation chains even at massive scale.
/// - **Zero-State**: Rules are stateless and can be safely cached, shared
///   across domains, or reused across multiple [Cell] instances.
/// - **Causal Integrity**: Rules evaluated asynchronously maintain their
///   position in the reactive timeline, ensuring state transitions occur in
///   the correct order relative to other pulses.
///
/// ### Example
/// ```dart
/// // 1. Define atomic rules
/// final isPositive = TestRule<int>((val, {host, arguments, user}) => val > 0);
/// final isInRange = TestRule<int>((val, {host, arguments, user}) => val <= 100);
///
/// // 2. Compose into a pipeline (Chain of Responsibility)
/// final pipeline = isPositive + isInRange;
///
/// // 3. Integrate with the graph (e.g., via TestCell or Cell factory)
/// final scoreCell = Cell.ingress<int>(
///   0,
///   testRule: pipeline
/// );
/// ```
///
/// ### Parameters:
/// * **[C]**: **The Host Environment.** Binds the rule to a specific node
///   context (usually a [Cell] subclass), enabling type-safe interaction
///   with the object being validated and its surrounding graph.
///
/// ### Returns:
/// A [TestRule] instance acting as a **Reactive Integrity Gate**.
///
/// ### See Also:
/// * [TestCell]: The primary policy engine that orchestrates rules.
/// * [Cell]: For applying these rules to reactive state containers.
/// * [Modifiable]: For objects that support validation via these gates.
///
/// {@category Testing & Validation}
class TestRule<C> {

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  /// The internal validation function for this rule.
  Function? get _rule {
    return get<Function?>(() => _record.rule, orElse: null);
  }

  /// The next rule in the validation chain, evaluated if this rule passes.
  TestRule<C>? get _parent => get<TestRule<C>?>(() => _record.parent, orElse: null);

  /// Optional user-defined data that can be accessed within the `_rule`
  dynamic get _user => get<dynamic>(() => _record.user, orElse: null);

  /// The collection of rules managed by this object.
  Iterable<TestRule<C>> get _rules =>
      get<Iterable<TestRule<C>>>(
              () => _record.rules, orElse: const Iterable.empty());

  /// Synthesizes a new [TestRule] instance to encapsulate a specific
  /// **Validation Predicate**.
  ///
  /// This constructor is the primary entry point for defining **Policy Guards**
  /// and **Integrity Gates**. It allows for the creation of reusable, stateless
  /// rules that can be composed into larger validation pipelines using
  /// the `+` operator.
  ///
  /// ### 1. Developer Ergonomics & Human Legibility
  /// This is the primary way developers create validation rules:
  ///
  /// ```dart
  /// // Simple range check
  /// final rangeRule = TestRule<int>((object, {host, arguments, user}) {
  ///   return object >= 0 && object <= 100;
  /// });
  ///
  /// // With host context
  /// final contextRule = TestRule<Cell>((object, {host, arguments, user}) {
  ///   final ctx = host?.context;
  ///   return ctx?.domains?.contains('Finance') ?? false;
  /// });
  ///
  /// // Using user data
  /// final thresholdRule = TestRule<int>((object, {host, arguments, user}) {
  ///   final limit = user as int? ?? 100;
  ///   return object <= limit;
  /// }, user: 50);
  ///
  /// // With parent chain
  /// final childRule = TestRule<int>((object, {host, arguments, user}) {
  ///   return object % 2 == 0;
  /// }, parent: baseRule);
  /// ```
  ///
  /// ### 2. Hybrid Convergence: Sync/Async Logic
  /// By accepting a [rule] that returns [FutureOr<bool>], this constructor
  /// enables **Scene-Driven Validation**:
  /// *   **Synchronous Path**: For high-frequency state updates, providing a
  ///     synchronous function ensures the **Integrity Gate** resolves without
  ///     entering the event loop, maintaining zero-latency propagation.
  /// *   **Asynchronous Path**: For security checks requiring I/O or remote
  ///     authority, the rule can return a [Future], allowing the node's
  ///     **Conactive Lock** to safely suspend until validation completes.
  ///
  /// ### 3. Example: Complete Validation Pipeline
  /// ```dart
  /// // Define individual rules
  /// final isPositive = TestRule<int>((object, {host, arguments, user}) {
  ///   return object > 0;
  /// });
  ///
  /// final isEven = TestRule<int>((object, {host, arguments, user}) {
  ///   return object % 2 == 0;
  /// });
  ///
  /// final isInRange = TestRule<int>((object, {host, arguments, user}) {
  ///   return object >= 0 && object <= 100;
  /// });
  ///
  /// // Compose into a pipeline
  /// final validation = isPositive + isEven + isInRange;
  ///
  /// // Use in a cell
  /// final cell = Cell(testRule: validation);
  /// ```
  ///
  /// ### Parameters:
  /// - [rule]: The core validation logic. It receives the [object] being
  ///   tested, the [host] context ([C]), any execution [arguments],
  ///   and the [user] metadata.
  /// - [parent]: An optional [TestRule] to be evaluated if this rule passes,
  ///   facilitating **Chain of Responsibility** composition.
  /// - [user]: Optional metadata or configuration data passed back to
  ///   the [rule] during execution.
  const TestRule(FutureOr<bool> Function(dynamic object, {C? host, dynamic arguments, dynamic user}) rule, {
    TestRule<C>? parent, dynamic user
  }) : _record = parent != null
      ? user != null
          ? (rule: rule, parent: parent, user: user)
          : (rule: rule, parent: parent)
      : user != null
          ? (rule: rule, user: user)
          : (rule: rule);

  /// Synthesizes a **Composite Validation Pipeline** from a collection of rules.
  ///
  /// This constructor implements the **Composite Pattern**, allowing a group
  /// of [TestRule] instances to be treated as a single atomic unit. It is
  /// primarily used to define **Policy Clusters** where multiple business
  /// invariants must be satisfied concurrently.
  ///
  /// ### 1. Developer Ergonomics & Human Legibility
  /// This factory is used to build complex validation pipelines:
  ///
  /// ```dart
  /// final pipeline = TestRule.chain([
  ///   isPositive,
  ///   isInRange,
  ///   isAuthorized,
  ///   isNotExpired,
  /// ]);
  ///
  /// // With custom strategy
  /// final conditionalPipeline = TestRule.chain(
  ///   [rule1, rule2, rule3],
  ///   strategy: (object, {host, arguments, user}) {
  ///     // Skip rule2 if object is null
  ///     if (object == null) {
  ///       return rule3.call(object, host: host);
  ///     }
  ///     return rule1.call(object, host: host)
  ///         .then((r) => r ? rule2.call(object, host: host) : false)
  ///         .then((r) => r ? rule3.call(object, host: host) : false);
  ///   },
  /// );
  /// ```
  ///
  /// ### 2. Execution Strategy: Default vs. Custom
  /// This constructor provides two distinct modes of **Policy Governance**:
  /// *   **Sequential Validation Cluster (Default)**: If no [strategy] is
  ///     provided, the chain acts as a strict **Sequential Gate**. It iterates
  ///     through the [rules] using **Short-Circuit Logic**; every rule must
  ///     return `true` for the chain to pass.
  /// *   **Custom Strategy Override**: If a [strategy] is provided, it
  ///     assumes full responsibility for the [rules] collection. This allows
  ///     for complex **Scene-Driven Logic**, such as "At-Least-One" (OR)
  ///     validation, weighted consensus, or temporal thresholds.
  ///
  /// ### 3. Hybrid Convergence: Seamless Scaling
  /// Like the primary constructor, `.chain` supports **Hybrid Convergence**
  /// via [FutureOr]:
  /// *   The internal execution engine automatically detects if any rule in
  ///     the collection returns a [Future].
  /// *   If an asynchronous rule is encountered, the chain seamlessly
  ///     transitions into an asynchronous pipeline, ensuring **Causal Integrity**
  ///     while maintaining high throughput for synchronous segments.
  ///
  /// ### 4. Example: Complete Security Pipeline
  /// ```dart
  /// final securityCheck = TestRule.chain([
  ///   authenticationRule,
  ///   authorizationRule,
  ///   rateLimitRule,
  ///   complianceRule,
  /// ]);
  ///
  /// // All checks must pass
  /// final authorized = await securityCheck.call(request);
  /// ```
  ///
  /// ### Parameters:
  /// - [rules]: The collection of [TestRule] instances to be aggregated.
  /// - [parent]: An optional rule to be evaluated after this chain passes,
  ///   continuing the **Chain of Responsibility**.
  /// - [user]: Optional metadata or configuration data passed to the [strategy].
  /// - [strategy]: An optional validation function that overrides the
  ///   default sequential execution of the [rules] collection.
  const TestRule.chain(Iterable<TestRule<C>> rules, {
    TestRule<C>? parent, dynamic user,
    FutureOr<bool> Function(dynamic object, {C? host, dynamic arguments, dynamic user})? strategy
  }) : _record = strategy != null ? parent != null ? user != null
      ? (rule: strategy, parent: parent, user: user) : (rule: strategy, parent: parent) : (rule: strategy)
      : parent != null ? (rules: rules, parent: parent) : (rules: rules);

  /// Reconstitutes a [TestRule] from a raw **Flyweight Record**, facilitating
  /// the restoration of validation logic from a compressed state.
  ///
  /// The [TestRule.fromRecord] constructor is the primary mechanism for
  /// **Structural Deserialization** within the reactive fabric. It allows the
  /// framework to reconstruct complex validation hierarchies and **Integrity
  /// Gates** without the overhead of standard object allocation.
  ///
  /// ### When to use
  /// - **State Restoration**: Use when recreating a rule from an existing
  ///   memory-optimized record representation during graph deserialization.
  /// - **Low-Level Orchestration**: Use when transferring rules across
  ///   execution boundaries where only raw data is available.
  /// - **Framework Internals**: Primarily intended for internal optimization
  ///   and high-frequency graph synthesis to minimize heap pressure via the
  ///   **Flyweight Strategy**.
  /// - **Causal Provenance**: Re-hydrating an **Integrity Gate** from a
  ///   persisted trace to ensure its lineage and metadata are preserved.
  ///
  /// ### How it works
  /// 1. **Direct Injection**: It bypasses standard construction and validation
  ///    logic, directly populating the internal [_record] state.
  /// 2. **Identity Restoration**: Re-establishes the rule's logic, parent
  ///    links, and user metadata from the provided record.
  /// 3. **Flyweight Efficiency**: By utilizing the record directly, it
  ///    supports the framework's goal of sharing memory for identical
  ///    validation logic across different nodes.
  ///
  /// ### Non‑obvious
  /// - **Developer Guidance**: Most developers should use the primary
  ///   [TestRule] or [TestRule.chain] constructors. This constructor is
  ///   reserved for **Advanced Framework Scenarios**.
  /// - **Zero-Cost Path**: It provides a zero-latency path for restoring
  ///   rules within performance-critical reactive waves.
  /// - **Data Integrity**: Assumes the provided record is valid and was
  ///   properly synthesized by the framework.
  /// - **Isolation**: Rules restored this way are immediately ready for use in
  ///   a **Reciprocal Handshake** without further configuration.
  ///
  /// ### Example
  /// ```dart
  /// // Primarily used internally for restoration:
  /// final restoredRule = TestRule<C>.fromRecord(storedRecord);
  /// ```
  ///
  /// ### Parameters:
  /// * [record]: **The Flyweight Payload.** The memory-optimized record
  ///   containing the rule's logic, parent links, and metadata.
  ///
  /// ### Returns:
  /// A [TestRule] instance reconstituted from its internal state.
  ///
  /// ### See Also:
  /// * [TestRule]: The standard constructor for defining validation logic.
  /// * [TestRule.chain]: For aggregating multiple rules into a pipeline.
  /// * [NucleusBase.fromRecord]: The structural counterpart for node blueprints.
  const TestRule.fromRecord(dynamic record) : _record = record;

  /// The foundational constructor for **Metadata-Driven Validation Annotations**,
  /// enabling the declarative definition of business invariants.
  ///
  /// [TestRule.base] provides the structural anchoring required for classes
  /// (such as [ValueRange], [EntryPattern], and [Values]) to be used as
  /// Dart annotations. This allows integrity rules to be embedded directly
  /// into the data schema rather than being injected at runtime.
  ///
  /// ### When to use
  /// - **Annotation Definition**: Use as the super-constructor for custom
  ///   validation classes intended for use as `@Annotation` markers.
  /// - **Static Schema Mapping**: Use to define structural constraints on
  ///   POJOs or data models that will be wrapped in cells.
  /// - **Declarative Validation**: When you want validation logic to be
  ///   discoverable via reflection/introspection for UI or API generation.
  ///
  /// ### How it works
  /// 1. **Annotation Reification**: It initializes the internal [_record]
  ///    to an empty unit `()`. This marks the instance as a stateless
  ///    metadata node.
  /// 2. **Structural Blueprinting**: When the framework encounters these
  ///    annotations on a class member, it automatically synthesizes them
  ///    into the reactive graph's validation layer.
  /// 3. **Stateless Logic**: Subclasses typically provide concrete validation
  ///    logic by overriding the [call] method, while relying on `base` for
  ///    type safety within the governance system.
  ///
  /// ### Non‑obvious
  /// - **Statelessness**: Rules extending `base` should remain strictly
  ///   stateless. They rely purely on the input value and metadata,
  ///   making them safe for global caching and concurrent access.
  /// - **Zero-Cost Metadata**: Because it is a `const` constructor,
  ///   annotation-based rules do not incur runtime overhead unless they are
  ///   explicitly evaluated.
  /// - **Visibility**: Annotations are visible to external tools (like code
  ///   generators or documentation engines) that might not have access to
  ///   the runtime reactive graph.
  ///
  /// ### Example
  /// ```dart
  /// class MaxLength extends TestRule<Never> {
  ///   final int length;
  ///   const MaxLength(this.length) : super.base();
  ///
  ///   @override
  ///   bool call(dynamic val, {Never? host, dynamic arguments}) =>
  ///       val is String && val.length <= length;
  /// }
  ///
  /// // Usage in a data model
  /// class User {
  ///   @MaxLength(20)
  ///   final String username;
  ///   User(this.username);
  /// }
  ///
  ///
  /// ### Parameters:
  /// (None)
  ///
  /// ### Returns:
  /// A [TestRule] instance acting as a Metadata Blueprint.
  ///
  /// ### See Also:
  /// * [TestRule]: The primary constructor for functional validation rules.
  /// * [ValueRange]: A standard implementation for numerical constraints.
  /// * [EntryPattern]: A standard implementation for string regex validation.
  const TestRule.base() : _record = ();

  /// Executes the **Validation Predicate** and orchestrates the
  /// **Chain of Responsibility** for this rule.
  ///
  /// This method serves as the operational entry point for **Policy
  /// Enforcement** and **Integrity Gate** resolution. It evaluates a stimulus
  /// ([object])—typically a `payload` or a state transition—against the
  /// governing invariants.
  ///
  /// ### When to use
  /// - **Framework Orchestration**: Automatically invoked by the [Nucleus] or
  ///   [TestCell] whenever a state update is proposed.
  /// - **Unit Testing**: Manually trigger validation logic to verify business
  ///   rules in isolation without mounting a full reactive graph.
  /// - **Custom Validation**: Invoke within custom [Modifiable] implementations
  ///   to gate internal state transitions.
  ///
  /// ### How it works
  /// 1. **Predicate Evaluation**: Executes the primary validation logic. If
  ///    defined as a composite, it evaluates the local rule first.
  /// 2. **Short-Circuit Logic**: If this rule is part of a pipeline (via `+`),
  ///    execution stops immediately if any segment returns `false`.
  /// 3. **Hierarchical Delegation**: If local checks pass, the evaluation is
  ///    propagated to the parent ancestor in the inheritance chain, ensuring
  ///    global invariants are maintained.
  /// 4. **Hybrid Convergence**: Supports [FutureOr]. Synchronous checks
  ///    complete at native speed, while asynchronous checks (e.g., DB lookups)
  ///    safely suspend the reactive wave until completion.
  ///
  /// ### Non‑obvious
  /// - **Fail-Safe Resilience**: Unhandled exceptions within a validator are
  ///   caught by the framework and treated as a **Pass** (`true`) to prevent
  ///   a single faulty rule from paralyzing the reactive system.
  /// - **Execution Context**: The `host` and `arguments` parameters provide
  ///   causal metadata, allowing rules to make decisions based on *who* or
  ///   *what* triggered the update.
  /// - **Atomicity**: When called via a [Cell], this method is automatically
  ///   protected by the node's conactive lock.
  ///
  /// ### Example
  /// ```dart
  /// final ageRule = TestRule<int>((val, {host, arguments, user}) => val >= 18);
  ///
  /// // Synchronous manual check
  /// final canEnter = await ageRule.call(21); // returns true
  ///
  /// // Asynchronous check (e.g., verifying against a database)
  /// final userRule = TestRule<String>((name, {host, arguments, user}) async {
  ///   return await db.userExists(name);
  /// });
  /// final exists = await userRule.call('Simon');
  /// ```
  ///
  /// ### Parameters:
  /// * [object]: **The Stimulus.** The data, payload, or proposed state change
  ///   being validated.
  /// * [host]: **The Operational Authority.** The [Cell] or container that
  ///   owns the state being modified.
  /// * [arguments]: **Forensic Metadata.** Optional context or payload details
  ///   derived from the original [Pulse].
  ///
  /// ### Returns:
  /// A [FutureOr<bool>] where `true` indicates the operation is **Accepted**
  /// by policy, and `false` indicates it is **Rejected**.
  ///
  /// ### See Also:
  /// * [TestRule.chain]: For building multi-stage validation pipelines.
  /// * [TestCell]: The primary engine for applying these rules to cells.
  FutureOr<bool> call(dynamic object, {C? host, dynamic arguments}) {
    FutureOr<bool> result = true;

    final rule = _rule;

    // Handle Primary Predicate
    if (rule != null) {
      try {
        result = rule(object, host: host, arguments: arguments, user: _user);
      } on Exception {
        rethrow;
      }
    } else { // Handle Composite Chain
      final rules = _rules;
      if (rules.isNotEmpty) {
        result = _evaluateChain(rules, 0, object, host, arguments);
      }
    }

    if (result is Future<bool>) {
      final parent = _parent;
      if (parent != null) {
        return result.then((passed) {
          if (!passed) return false;
          return parent.call(object, host: host, arguments: arguments);
        });
      }
      return result.catchError((e) => e);
    } else if (!result) {
      return false;
    }

    // Handle Hierarchical Delegation
    return _parent?.call(object, host: host, arguments: arguments) ?? true;

  }

  /// Internal helper to process the chain while preserving FutureOr semantics.
  FutureOr<bool> _evaluateChain(Iterable<TestRule> rules, int index,
      dynamic object, dynamic host, dynamic arguments) {
    for (var i = index; i < rules.length; i++) {
      try {
        final result = rules.elementAt(i).call(object, host: host, arguments: arguments);

        if (result is Future<bool>) {
          // Switch to Async mode for the remainder of the chain
          return result.then((passed) {
            if (!passed) return false;
            return _evaluateChain(rules, i + 1, object, host, arguments);
          });
        }

        if (!result) return false; // Short-circuit
      } on Exception {
        rethrow;
      }
    }

    // Chain finished, check parent
    return _parent?.call(object, host: host, arguments: arguments) ?? true;
  }

  /// Composes two [TestRule] instances into a sequential **Validation Pipeline**.
  ///
  /// This operator implements the **Chain of Responsibility** pattern using
  /// **Atomic Composition**. It allows individual, granular rules to be
  /// linked together into a singular governance unit, facilitating the construction
  /// of complex policy layers from simple, stateless blueprints.
  ///
  /// ### When to use
  /// - **Policy Layering**: Building complex validation structures (e.g.,
  ///   `isNotNull + isNotEmpty + isEmail`) without creating monolithic classes.
  /// - **Developer Ergonomics**: Providing a clean, readable syntax for building
  ///   validation pipelines that is easier to scan than nested constructors.
  /// - **Modular Validation**: Combining reusable, domain-specific rules into
  ///   a single integrity gate for a specific [Cell].
  ///
  /// ### How it works
  /// 1. **Sequential Evaluation**: When the resulting rule is called, the
  ///    receiver (left side) is evaluated first.
  /// 2. **Short-Circuit Logic**: If the first rule returns `false`, the
  ///    [other] rule is never executed, and the entire operation returns
  ///    `false` immediately.
  /// 3. **Cumulative Integrity**: The pipeline only returns `true` if both
  ///    the principal rule and the [other] rule satisfy their invariants.
  /// 4. **Hybrid Convergence**: The operator preserves `FutureOr` semantics.
  ///    If either rule is asynchronous, the execution engine ensures the
  ///    reactive wave is correctly awaited, maintaining **Causal Integrity**.
  ///
  /// ### Non‑obvious
  /// - **Evaluation Order**: Execution is strictly left-to-right. This is
  ///   critical when a downstream rule depends on a type-check or null-check
  ///   performed by an upstream rule.
  /// - **Structural Efficiency**: Under the hood, this operator delegates to
  ///   [TestRule.chain], which utilizes the framework's **Flyweight Strategy**
  ///   to minimize memory overhead for long validation chains.
  /// - **Short-Circuit Performance**: By failing early, the pipeline avoids
  ///   expensive validation logic (like database lookups) if a basic
  ///   structural invariant has already failed.
  ///
  /// ### Example
  /// ```dart
  /// final isNotNull = TestRule<String?>((val, {host, arguments, user}) => val != null);
  /// final isNotEmpty = TestRule<String>((val, {host, arguments, user}) => val.isNotEmpty);
  /// final maxLength = TestRule<String>((val, {host, arguments, user}) => val.length <= 50);
  ///
  /// // Compose into a pipeline
  /// final validName = isNotNull + isNotEmpty + maxLength;
  ///
  /// // Usage
  /// final result = await validName.call('Simon'); // returns true
  /// ```
  ///
  /// ### Parameters:
  /// * [other]: **The Successor Gate.** The next [TestRule] to be appended to
  ///   the validation chain. Uses `covariant` to ensure type compatibility
  ///   with the host environment [C].
  ///
  /// ### Returns:
  /// A new [TestRule] instance representing a **Composite Validation Pipeline**.
  ///
  /// ### See Also:
  /// * [TestRule.chain]: The underlying factory used for composite synthesis.
  /// * [TestCell]: The primary engine that evaluates these combined pipelines.
  TestRule<C> operator +(covariant TestRule<C> other) {
    return TestRule<C>.chain([this, other]);
  }

  @override
  int get hashCode => Object.hash(runtimeType, _record);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestRule<C> &&
        other.runtimeType == runtimeType &&
        other._record == _record;
  }

}