// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../cell_tissue.dart';

/// A specialised, multi‑vector **Security and Validation Engine** designed to
/// govern the structural integrity and operational boundaries of [Tissue]
/// containers (Lists, Sets, Maps, Queues, Values).
///
/// [TestTissue] is the cornerstone of the framework's **Invariant Enforcement**
/// for collections. It extends the base [TestCell] logic to provide a
/// comprehensive **Integrity Gate** that monitors every mutation, membership
/// change, and reactive bond within the collection graph.
///
/// ### When to use
/// Use [TestTissue] whenever you need to enforce business rules, security
/// boundaries, or data integrity on a reactive collection. The framework uses
/// it internally for every mutation, but you supply your own when creating a
/// tissue:
/// ```dart
/// final list = TissueList<int>(
///   testRule: TestTissue<int>((v) => v >= 0 && v <= 100),
/// );
/// ```
///
/// You almost never need to construct a [TestTissue] from scratch. Start with
/// one of the predefined policies:
/// - [TestTissue.allowAll] – the default, no restrictions.
/// - [TestTissue.readOnly] – blocks all mutations, perfect for deputies.
///
/// To define your own, use the constructor with a simple validation function,
/// then compose with others:
/// ```dart
/// final isPositive = TestTissue<int, TissueList<int>>(
///   (value, {host, ...}) => value > 0,
/// );
/// final hasPermission = TestTissue<Cell, TissueList<Cell>>(
///   (_, {host, ...}) => host.context.hasRole('admin'),
/// );
/// final policy = isPositive + hasPermission;
/// ```
///
/// ### How it works
/// - The [TestTissue] is attached to a collection at creation time.
/// - Every operation (adding an element, removing, clearing, etc.) passes
///   through the validation pipeline.
/// - The pipeline is a chain of rules; each rule returns `true` to allow or
///   `false` to block.
/// - Rules can be synchronous or asynchronous ([FutureOr<bool>]).
/// - The `+` operator composes rules into a single [TestTissue] that evaluates
///   them in sequence (short‑circuiting on `false`).
///
/// Unlike a generic [TestCell], [TestTissue] understands **collection
/// semantics**. It provides a specialised `element` method that validates
/// individual members, and it integrates with the `modifiable` manifest to
/// block entire categories of operations (e.g., `clear`).
///
/// ### Non‑obvious
/// - A deputy (created via `deputy()`) gets its own [TestTissue], layered
///   on top of the principal's rule. You can narrow permissions, never widen.
/// - If a rule throws an exception, the framework treats it as a `true` (pass)
///   when the host is ungoverned, or `false` (fail) when governed.
/// - The [TestTissue] is a flyweight – many collections can share the same
///   policy instance without extra memory.
/// - The `element` validation is **not** automatically applied to every
///   element in an `addAll` – it's applied per element, and if one fails,
///   the behaviour depends on the collection type. For sets, a failed element
///   is simply skipped; for lists, the entire operation may be rejected.
///
/// ### Type Parameters:
/// * [E]: The type of elements managed by the target [Tissue].
/// * [C]: The concrete type of the [Tissue] being governed (e.g.,
///   `TissueList<E>` or `TissueSet<E>`).
///
/// ### Example: E‑commerce product list validation
/// ```dart
/// final productPolicy = TestTissue<Product, TissueList<Product>>(
///   (product, {host, arguments, user}) {
///     // Only allow products with positive price and non‑empty name
///     return product.price > 0 && product.name.isNotEmpty;
///   },
/// ) + TestTissue<Product, TissueList<Product>>(
///   (_, {host, ...}) => host.length < 100, // max 100 items
/// );
/// ```
///
/// See also:
/// - [TestCell] – the base validation logic for all reactive cells.
/// - [TestElementRule] – the specific interface for membership validation.
/// - [TissueNucleus] – where these rules are attached to the reactive blueprint.
class TestTissue<E, C extends Tissue<E>> extends TestCell<C> implements TestElementRule<E,C> {

  /// Maximum size constant used for unbounded collections.
  static const unlimitedLength = -1;

  /// A predefined, global singleton representing an **Unrestricted Permission
  /// Policy** for reactive collections.
  ///
  /// [allowAll] serves as the "Identity Element" of the [TestTissue] validation
  /// system. It provides a no‑op implementation of the **Integrity Gate**,
  /// where every validation check – regardless of the operation, element type,
  /// or execution context – is automatically authorised.
  ///
  /// ### When to use
  /// This is the default policy for collections when no custom rule is
  /// provided. It's safe to use for non‑critical data or when you don't
  /// need validation.
  ///
  /// ### How it works
  /// It unconditionally returns `true` for all validation requests. It is a
  /// singleton, so millions of collections can share it without memory
  /// overhead.
  ///
  /// ### Non‑obvious
  /// - When combined with other rules via `+`, it acts as a no‑op – the
  ///   other rule's logic is preserved.
  /// - It is the fallback authority in deputy chains: if no restrictive
  ///   rule intercepts an operation, [allowAll] permits it.
  ///
  /// ### Example
  /// ```dart
  /// final list = TissueList<int>(); // testRule defaults to allowAll
  /// ```
  ///
  /// See also:
  /// - [readOnly]: The restrictive counterpart for enforcing immutability.
  static const allowAll = _TestTissueNever();

  /// A predefined, immutable security policy that enforces a strict **Read‑Only
  /// Mutation Barrier** specifically for reactive collections.
  ///
  /// [readOnly] is a core architectural constant used to implement the
  /// **Deputy Pattern** for unmodifiable collection views. It serves as a
  /// specialised gatekeeper that targets and blocks any attempt to execute
  /// functions or commands defined as "modifiable" by the host [Tissue].
  ///
  /// ### When to use
  /// Use this when you need to share a collection with code that should only
  /// read data, never write it – e.g., passing a list to a UI widget.
  /// ```dart
  /// final readOnly = sourceList.deputy(testRule: TestTissue.readOnly);
  /// ```
  ///
  /// ### How it works
  /// - It intercepts all mutation methods (e.g., `add`, `remove`, `clear`).
  /// - If the requested function is in the host's `modifiable` whitelist,
  ///   the rule returns `true` (disallow), effectively blocking the mutation.
  /// - It does **not** block observation, iteration, or pulse propagation.
  ///   A read‑only deputy remains a "Live" node that reflects the source state
  ///   in real time; it simply lacks "Write‑Back" rights.
  ///
  /// ### Non‑obvious
  /// - This is a singleton – all unmodifiable collection deputies share the
  ///   exact same validation logic, reducing memory footprint.
  /// - It only blocks *structural* mutations. If the collection contains
  ///   mutable cells, those cells can still be mutated directly unless
  ///   `unmodifiableElement` is used.
  ///
  /// ### Example
  /// ```dart
  /// final source = TissueList<String>(['A', 'B']);
  /// final readOnly = source.deputy(testRule: TestTissue.readOnly);
  /// print(readOnly[0]); // 'A' – works
  /// readOnly.add('C'); // blocked – throws UnsupportedError
  /// source.add('C');   // allowed – readOnly reflects the change
  /// ```
  static const readOnly = _TestTissueReadOnly();

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  Iterable<TestRule<C>> get _rules => get<Iterable<TestRule<C>>>(_record.rules, orElse: const Iterable.empty());

  /// Creates a new [TestTissue] validation rule for reactive collections.
  ///
  /// ### When to use
  /// Use this when you need a simple, atomic validation rule for a collection.
  /// For multiple rules, compose them with `+` or use [TestTissue.chain].
  ///
  /// ### How it works
  /// The [rule] function is called for every validation request. It receives
  /// the object being validated (element, pulse, or function), the host
  /// collection, optional arguments, and optional user data. Return `true` to
  /// allow, `false` to block.
  ///
  /// ### Non‑obvious
  /// - The [rule] is polymorphic – it can handle elements (for membership),
  ///   functions (for actions), and pulses (for signals). The framework
  ///   routes the call appropriately.
  /// - If the [rule] throws an exception, the behaviour depends on whether
  ///   the host is governed (fail) or ungoverned (pass).
  /// - The optional [parent] allows policy inheritance – the parent rule is
  ///   checked after this rule (if this rule passes).
  ///
  /// ### Example
  /// ```dart
  /// final positiveRule = TestTissue<int, TissueList<int>>(
  ///   (value, {host, ...}) => value > 0,
  /// );
  /// final adminRule = TestTissue<Cell, TissueList<Cell>>(
  ///   (_, {host, ...}) => host.context.isAdmin,
  /// );
  /// final policy = positiveRule + adminRule;
  /// ```
  ///
  /// ### Parameters:
  /// - [rule]: The validation logic. Must return `FutureOr<bool>`.
  /// - [parent]: An optional [TestTissue] to chain after this rule.
  /// - [user]: Optional metadata for auditing or context.
  const TestTissue(FutureOr<bool> Function(dynamic object, {C? host, dynamic arguments, dynamic user}) rule, {TestTissue<E,C>? parent, dynamic user})
      : this.fromRecord(parent != null ? user != null
      ? (rule: rule, parent: parent, user: user) : (rule: rule, parent: parent) : (rule: rule)
  );

  /// Creates a **Composite Validation Pipeline** by aggregating multiple
  /// specialised rules into a single, unified **Integrity Gate**.
  ///
  /// ### When to use
  /// Use this when you need to combine several independent validations into a
  /// single policy – e.g., `isPositive + isAuthorized + isInRange`. It's an
  /// alternative to chaining with `+` and is useful when you have a dynamic
  /// list of rules.
  ///
  /// ### How it works
  /// The rules are executed in the order given; if any rule returns `false`,
  /// the chain short‑circuits and the whole validation fails.
  ///
  /// ### Non‑obvious
  /// - You can provide a custom [fn] that acts as an "Omniscient Guard,"
  ///   executing alongside the specialised [rules]. If provided, it overrides
  ///   the default sequential evaluation.
  /// - If a rule returns a `Future`, the chain automatically becomes
  ///   asynchronous and waits for it.
  /// - The default strategy is **fail‑fast** – any rule returning `false`
  ///   stops the pipeline immediately.
  ///
  /// ### Example
  /// ```dart
  /// final policy = TestTissue.chain([
  ///   isPositive,
  ///   isAuthorized,
  ///   isInRange,
  ///   isNotExpired,
  /// ]);
  /// ```
  ///
  /// ### Parameters:
  /// - [rules]: The collection of [TestRule] instances to be chained.
  /// - [parent]: An optional [TestTissue] to evaluate after the chain.
  /// - [user]: Optional metadata for the chain.
  /// - [strategy]: An optional override function that takes full control of
  ///   the validation logic; if provided, the default sequential evaluation
  ///   is bypassed.
  const TestTissue.chain(Iterable<TestRule<C>> rules, {TestTissue<E,C>? parent, dynamic user,
    FutureOr<bool> Function(dynamic object, {C? host, dynamic arguments, dynamic user})? strategy})
      : this.fromRecord(strategy != null ? parent != null
      ? user != null ? (rules: rules, rule: strategy, parent: parent, user: user) : (rules: rules, rule: strategy, parent: parent)
      : user != null ? (rules: rules, rule: strategy, user: user) : (rules: rules, rule: strategy)
      : (rules: rules)
  );

  /// Internal, foundational constructor that instantiates a [TestTissue]
  /// directly from a structured [record] configuration.
  ///
  /// ### When to use
  /// You don't call this directly. It's part of the Flyweight Record Pattern
  /// used internally for memory optimisation.
  const TestTissue.fromRecord(super.record) : _record = record, super.fromRecord();

  /// The primary execution entry point for the [TestTissue] validation engine.
  ///
  /// ### When to use
  /// You rarely call this directly – the framework invokes it automatically
  /// during validation. You might call it for testing.
  ///
  /// ### How it works
  /// It acts as a polymorphic dispatcher:
  /// - If the [object] is an element of type [E] and the [arguments] are a
  ///   [Function] (a mutation vector), it routes the call to the specialised
  ///   [element] method.
  /// - Otherwise, it falls back to the base [TestCell.call] logic, which
  ///   handles actions, pulses, and links.
  ///
  /// ### Non‑obvious
  /// - This routing ensures that element‑level validations are only applied
  ///   when an element is actually being added or updated.
  /// - The [arguments] parameter is typically a mutation function like `add`
  ///   or `remove`.
  ///
  /// ### Parameters:
  /// - [object]: The primary subject (element, pulse, or function).
  /// - [host]: The collection instance being mutated.
  /// - [arguments]: Supplemental metadata for the operation.
  ///
  /// ### Returns:
  /// `true` if the operation is authorised; `false` otherwise.
  @override
  FutureOr<bool> call(dynamic object, {C? host, dynamic arguments}) {
    if (host != null && (object is E && arguments is Function)) {
      return element(object, host: host, action: arguments);
    }
    return super.call(object, host: host, arguments: arguments);
  }

  /// Specialised entry point for **Element‑Level Governance**, determining if a
  /// specific member [E] is authorised to be part of the [Tissue] [host].
  ///
  /// ### When to use
  /// This is the core membership validation method. It's called automatically
  /// by the framework whenever an element is added, updated, or checked.
  ///
  /// ### How it works
  /// - It collects all [TestElementRule]s in the policy chain.
  /// - Each rule is given the element, the host collection, and the mutation
  ///   action (e.g., `add`, `remove`).
  /// - If any rule returns `false`, the element is rejected.
  /// - If all pass, the element is authorised.
  ///
  /// ### Non‑obvious
  /// - The [action] parameter allows **differentiated validation** – a rule
  ///   might permit an element for a `contains` check but forbid it for an
  ///   `add` mutation.
  /// - If a rule returns a `Future`, the validation suspends until the
  ///   future completes.
  /// - Unhandled exceptions default to `true` (pass) to preserve system
  ///   liveness.
  ///
  /// ### Example
  /// ```dart
  /// final policy = TestTissue<String, TissueList<String>>(
  ///   (element, {host, action, ...}) {
  ///     if (action == add) return element.isNotEmpty;
  ///     return true;
  ///   },
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [element]: The proposed member being evaluated.
  /// - [host]: The live collection instance.
  /// - [action]: The mutation vector triggering the request (e.g., `add`).
  ///
  /// ### Returns:
  /// `true` if the element is authorised; `false` otherwise.
  @override
  FutureOr<bool> element(covariant E? element, {required C host, Function? action}) {
    final rules = _rules.whereType<TestElementRule<E, C>>().toList();

    // Internal recursive evaluator to handle FutureOr branching
    FutureOr<bool> runRules(int index) {
      for (var i = index; i < rules.length; i++) {
        final result = rules[i].element(element, host: host);

        // Branching: If a rule returns a Future, chain the rest of the stack
        if (result is Future<bool>) {
          return result.then((passed) {
            if (!passed) return false; // Fail Fast
            return runRules(i + 1);    // Continue chain
          });
        }

        // Synchronous Path
        if (!result) return false;
      }
      return true; // All rules passed
    }

    return runRules(0);
  }

  /// Composes this validation policy with another [TestRule], creating a
  /// **Composite Security Stack** through the **Composite Pattern**.
  ///
  /// ### When to use
  /// Use this operator to build complex validation logic from simple,
  /// reusable rules. It's the most common way to combine rules.
  ///
  /// ### How it works
  /// It returns a new [TestTissue] where the current rule (`this`) is
  /// evaluated first, and if it passes, the [other] rule is evaluated next.
  /// If `this` returns `false`, `other` is never called (short‑circuit).
  ///
  /// ### Non‑obvious
  /// - The order matters: `ruleA + ruleB` means ruleA is evaluated first.
  /// - The resulting policy is still a [TestTissue] and can be further
  ///   composed.
  /// - This is the engine behind **Mandate Attenuation** – a deputy can
  ///   add a restrictive rule on top of the principal's existing policy.
  ///
  /// ### Example
  /// ```dart
  /// final policy = isPositive + isAuthorized + isInRange;
  /// ```
  ///
  /// ### Parameters:
  /// - [other]: The additional rule to append to the validation stack.
  ///
  /// ### Returns:
  /// A new [TestTissue] representing the unified, layered logic of both
  /// contributing policies.
  @override
  TestTissue<E,C> operator +(covariant TestRule<C> other) {
    return TestTissue<E,C>.chain([this, other]);
  }

}

/// A specialised, high‑fidelity security rule designed to govern **Member‑Level
/// Integrity** within a [Tissue] container.
///
/// [TestElementRule] is the primary architectural component for enforcing
/// **Structural Invariants** on the individual elements of a reactive collection.
/// While general rules might govern a collection's lifecycle or global capabilities,
/// this rule focuses exclusively on the "Ingress and Egress" of data points,
/// acting as an **Integrity Barrier** that protects the consistency of the
/// collection's internal state.
///
/// ### When to use
/// Use this when you need to validate elements based on their value, state,
/// or relationship to the host collection, and you want to separate that
/// logic from action or pulse validation.
///
/// You rarely need to use [TestElementRule] directly. Instead, use the
/// [TestTissue] constructor, which accepts a rule function and automatically
/// wraps it in the appropriate element‑specific logic. This class is exposed
/// primarily for advanced composition or when building custom policy layers.
///
/// ### How it works
/// - The rule is attached to a collection via [TestTissue] and evaluated
///   whenever an element is added, removed, or updated.
/// - The [rule] function receives the element, the host collection, the
///   mutation action (e.g., `add`, `remove`), and optional user data.
/// - Return `true` to allow the element, `false` to block it.
/// - Rules are composed with `+` (via the base [TestRule]).
///
/// ### Non‑obvious
/// - The rule is only evaluated when the object is of type [E] and the
///   action is a function. This prevents it from accidentally blocking
///   other types of validation (like pulses or links).
/// - The [action] parameter enables **action‑aware validation**. For example,
///   you might allow a value in a `contains` check but forbid it in an `add`.
/// - Like all [TestRule]s, it supports asynchronous validation via
///   `FutureOr<bool>`.
///
/// ### Example
/// ```dart
/// final elementRule = TestElementRule<String, TissueList<String>>(
///   (element, {host, action, user}) {
///     // Only allow non‑empty strings for `add`, but allow anything for `remove`
///     if (action == add) return element.isNotEmpty;
///     return true;
///   },
/// );
/// ```
///
/// ### Type Parameters:
/// * [E]: The type of the element being validated.
/// * [C]: The concrete type of the [Tissue] host.
///
/// See also:
/// - [TestTissue] – the main policy engine that uses this rule.
/// - [TestActionRule] – for validating the action itself.
/// - [TestInstruction] – for validating incoming signals.
class TestElementRule<E, C extends Tissue<E>> extends TestRule<C> {

  /// Creates a specialised **Integrity Guard** for individual collection
  /// members, enforcing **Member‑Level Governance** and **Structural Invariants**.
  ///
  /// ### When to use
  /// Use this when you need to implement granular membership validation that
  /// is specific to a single element type. For most cases, using the
  /// [TestTissue] constructor with a rule function is simpler and more
  /// ergonomic.
  ///
  /// ### How it works
  /// The provided [rule] function is called whenever an element is being
  /// evaluated for membership. It receives the element, the host collection,
  /// the mutation action, and optional user data.
  ///
  /// ### Non‑obvious
  /// - The rule is wrapped in a generic [TestRule] that only triggers if the
  ///   object is of type [E] and the arguments are a [Function].
  /// - The [action] parameter allows you to differentiate between `add`,
  ///   `remove`, `update`, and other operations.
  /// - The optional [parent] allows chaining with another element rule.
  ///
  /// ### Example
  /// ```dart
  /// final positiveRule = TestElementRule<int, TissueList<int>>(
  ///   (element, {host, action, user}) => element > 0,
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// - [rule]: The validation predicate.
  /// - [parent]: An optional parent rule for inheritance.
  /// - [user]: Optional metadata passed to the rule function.
  TestElementRule(bool Function(E? element, {required C host, Function? action, dynamic user}) rule, {super.parent, dynamic user})
      : super((dynamic object, {C? host, dynamic arguments, dynamic user}) {
    return host != null && ((arguments is Function && object is E?) || object is E)
        ? rule(object, host: host, action: arguments, user: user) : true;
  });

  /// Evaluates whether a specific member [E] is authorised to participate in
  /// a structural transition within the host [Tissue].
  ///
  /// ### When to use
  /// You don't call this directly – the framework invokes it automatically
  /// during membership validation. It can be called manually for testing.
  ///
  /// ### How it works
  /// It delegates to the base `call` method, which evaluates the rule and
  /// parent chain. The `call` method has already been configured to only
  /// trigger for elements of type [E].
  ///
  /// ### Parameters:
  /// - [element]: The proposed member being evaluated.
  /// - [host]: The live collection instance.
  /// - [action]: The mutation vector (e.g., `add`, `remove`).
  ///
  /// ### Returns:
  /// `true` if the element is authorised; `false` otherwise.
  FutureOr<bool> element(E? element, {required C host, Function? action}) {
    return call(element, host: host, arguments: action);
  }

}