// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell.dart';

/// The central validation gate for a [Cell] – it decides what's allowed.
///
/// Every reactive node has a [TestCell] that governs four kinds of actions:
/// - **State changes** (the core validation)
/// - **Function execution** ([TestActionRule])
/// - **Linking** ([TestLinkRule])
/// - **Pulse processing** ([TestPulseRule])
///
/// You compose individual rules into a single policy using the `+` operator.
///
/// ### When to use
/// Most of the time you don't need to build a [TestCell] from scratch.
/// Start with one of the predefined policies:
/// * [allowAll] – the default, no restrictions.
/// * [readOnly] – blocks mutations, allows observation.
///
/// To define your own, use the constructor with a simple validation function,
/// then compose with others:
/// ```dart
/// final isPositive = TestCell<int>((value, {host, arguments, user}) => value > 0);
/// final hasPermission = TestCell<Cell>((_, {host, ...}) => host.context.hasRole('admin'));
/// final policy = isPositive + hasPermission;
/// ```
///
/// Use [TestCell] whenever you need to enforce business rules, security
/// boundaries, or data integrity on a cell. The framework uses it internally
/// for every validation, but you can supply your own when creating a cell:
/// ```dart
/// final cell = Cell(testRule: myPolicy);
/// ```
///
/// ### How it works
/// - The [TestCell] is attached to a cell at creation time.
/// - Every operation (state change, action, link, pulse) passes through the
///   [TestCell]'s validation pipeline.
/// - The pipeline is a chain of rules; each rule returns `true` to allow or
///   `false` to block.
/// - Rules can be synchronous or asynchronous ([FutureOr<bool>]).
/// - The `+` operator composes rules into a single [TestCell] that evaluates
///   them in sequence (short‑circuiting on `false`).
///
/// ### Example: A complete policy
/// ```dart
/// final rangeRule = TestCell<int>((value, ...) => value >= 0 && value <= 100);
/// final actionRule = TestActionRule<Cell>((action, ...) => action is ReadAction);
/// final linkRule = TestLinkRule<Cell>((link, ...) => link.context.domains == host.context.domains);
/// final pulseRule = TestPulseRule<Cell>((pulse, ...) => pulse.priority > 50);
///
/// final policy = rangeRule + actionRule + linkRule + pulseRule;
/// ```
///
/// See also:
/// * [TestActionRule] for action‑specific validation.
/// * [TestLinkRule] for link‑specific validation.
/// * [TestPulseRule] for pulse‑specific validation.
/// * [TestRule] for the base validation contract.
/// - **HowTo**: See `guide/HowTo-TestCell.md` for a guide on implementing
///   custom validation policies and integrity gates.
///
/// {@category Testing & Validation}
///
/// ### AI Agent Guide
/// **Layer:** Cell — the integrity gate for Cell nodes. Not an operator (Flow), not a book (Tissue).
/// **When to use:** `testRule: TestCell(...)` on **ingress / state / toHandle** only, when a BRD quality rule names that field.
/// **When NOT to use:**
///   {@macro ai-do-not-testcell-on-tissue}
/// **Live signature:** `TestCell<C extends Cell>(...)` — chain with `+`; `TestCell.allowAll` / `TestCell.readOnly` constants — pinned at `cell: 1.1.0`
/// **Do NOT confuse with:** `TestTissue` (`cell_tissue`, for Tissue books). They are not subtypes.
/// **Guide:** `guide/HowTo-TestCell.md` (integrity gates)
/// **Example:** `example/ingress_demo.dart`
/// **Cross-layer:** every Tissue book takes `TestTissue`, never `TestCell`.
/// **Minimal compilable example**
/// ```dart
/// final gate = TestCell((v, {arguments, host, user}) => v is int && v >= 0);
/// final c = Cell.ingress<int>(testRule: gate);
/// c.emit(1);
/// c.emit(-1); // rejected by the gate
/// print('ok');
/// ```
class TestCell<C extends Cell> extends TestRule<C>
    implements TestActionRule<C>, TestLinkRule<C>, TestPulseRule<C> {
  /// A policy that allows everything – the default.
  ///
  /// Use this when you have no restrictions. It's a singleton, so no memory
  /// overhead.
  ///
  /// ```dart
  /// final cell = Cell(); // testRule defaults to allowAll
  /// ```
  static const allowAll = TestPasses();

  /// A policy that blocks mutations through the [Cell.apply] gateway –
  /// read‑only.
  ///
  /// Use this to create a view that can observe but not change state through
  /// whitelisted actions.
  ///
  static const readOnly = _TestCellReadOnly<Cell>();

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  Iterable<TestRule<C>> get _rules {
    return get<Iterable<TestRule<C>>>(() => _record.rules,
        orElse: const Iterable.empty());
  }

  /// The next rule in the validation chain, evaluated if this rule passes.
  TestCell<C>? get _parent =>
      get<TestCell<C>?>(() => _record.parent, orElse: null);

  /// Creates an [TestCell] with a single validation rule.
  ///
  /// This is the primary way to define a custom policy. The [rule] function
  /// receives the object being validated (state, pulse, link, or action), the
  /// host cell, and optional arguments and user data. Return `true` to allow
  /// the operation, `false` to block it.
  ///
  /// ### When to use
  /// Use this when you need a simple, atomic validation rule. For multiple
  /// rules, compose them with `+` or use [TestCell.chain].
  ///
  /// ### How it works
  /// - The [rule] is evaluated for every validation request.
  /// - If the rule returns a [Future], the validation is asynchronous; the cell
  ///   will wait for it to complete.
  /// - The optional [parent] allows policy inheritance – the parent rule is
  ///   checked after this rule (if this rule passes).
  ///
  /// ### Example
  /// ```dart
  /// final positiveRule = TestCell<int>((value, {host, ...}) => value > 0);
  /// final adminRule = TestCell<Cell>((_, {host, ...}) => host.context.isAdmin);
  /// final policy = positiveRule + adminRule;
  /// ```
  ///
  /// ### Parameters:
  /// - [rule]: The validation logic. Must be a function taking `(object, {host, arguments, user})` and returning `FutureOr<bool>`.
  /// - [parent]: An optional [TestCell] to chain after this rule.
  /// - [user]: Optional metadata for auditing or context.
  const TestCell(
      FutureOr<bool> Function(dynamic object,
              {C? host, dynamic arguments, dynamic user})
          rule,
      {TestCell<C>? parent,
      dynamic user})
      : this.fromRecord(parent != null
            ? user != null
                ? (rule: rule, parent: parent, user: user)
                : (rule: rule, parent: parent)
            : user != null
                ? (rule: rule, user: user)
                : (rule: rule));

  /// Synthesizes a **Composite Validation Pipeline** by aggregating multiple
  /// specialized rules into a single, unified **Integrity Gate**.
  ///
  /// This constructor implements the **Composite Pattern**, allowing an
  /// [Iterable] of [TestRule] instances to be treated as a single atomic unit
  /// of governance. It is primarily used to define **Policy Clusters** where
  /// multiple independent invariants must be satisfied concurrently to
  /// authorize a reactive operation.
  ///
  /// ### When to use
  /// Use this when you need to combine several independent validations into a
  /// single policy – e.g., `isPositive + isAuthorized + isInRange`.
  ///
  /// ### How it works
  /// The rules are executed in the order given; if any rule returns `false`,
  /// the chain short‑circuits and the whole validation fails.
  /// - You can optionally provide a custom [strategy] that overrides the default
  ///   sequential execution, allowing you to implement more complex logic
  ///   (e.g., "at least one of these rules must pass").
  /// - The [parent] link continues the chain after the local rules.
  ///
  /// ### Example
  /// ```dart
  /// final policy = TestCell.chain([
  ///   isPositive,
  ///   isAuthorized,
  ///   isInRange,
  ///   isNotExpired,
  /// ]);
  ///
  /// // With custom strategy
  /// final conditionalPolicy = TestCell.chain(
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
  /// ### Parameters:
  /// - [rules]: The collection of [TestRule] instances to be chained.
  /// - [parent]: An optional [TestCell] to evaluate after the chain.
  /// - [user]: Optional metadata for the chain.
  /// - [strategy]: An optional override function that takes full control of
  ///   the validation logic; if provided, the default sequential evaluation
  ///   is bypassed.
  const TestCell.chain(Iterable<TestRule<C>> rules,
      {TestCell<C>? parent,
      dynamic user,
      FutureOr<bool> Function(dynamic object,
              {C? host, dynamic arguments, dynamic user})?
          strategy})
      : this.fromRecord(strategy != null
            ? parent != null
                ? user != null
                    ? (rules: rules, rule: strategy, parent: parent, user: user)
                    : (rules: rules, rule: strategy, parent: parent)
                : user != null
                    ? (rules: rules, rule: strategy, user: user)
                    : (rules: rules, rule: strategy)
            : parent != null
                ? user != null
                    ? (rules: rules, parent: parent, user: user)
                    : (rules: rules, parent: parent)
                : user != null
                    ? (rules: rules, user: user)
                    : (rules: rules));

  /// Creates a [TestCell] instance directly from a raw [Record] blueprint.
  ///
  /// This constructor is part of the **Flyweight Pattern** implementation,
  /// allowing the framework to restore validation logic from a compressed
  /// state representation. It is primarily used during **Structural
  /// Deserialization** or when moving rules across memory boundaries.
  ///
  /// ### When to use
  /// You rarely need this – it's for internal framework use.
  ///
  /// ### How it works
  /// It directly assigns the provided record to internal storage, bypassing
  /// the normal parameter validation. This is a performance optimisation for
  /// cases where the record is already known to be valid.
  ///
  const TestCell.fromRecord(super.record)
      : _record = record,
        super.fromRecord();

  /// The primary entry point for the **Integrity Gate**, executing the
  /// validation pipeline for a specific [object] or state mutation.
  ///
  /// This method serves as the **Somatic Sensory Unit** of the cell. It
  /// determines whether an incoming stimulus, a proposed value, or an
  /// internal transformation aligns with the defined [Governance] and
  /// [Context] laws.
  ///
  /// ### When to use
  /// You typically don't call this directly – the framework invokes it
  /// automatically during validation. You might call it for testing.
  ///
  /// ### How it works
  /// - It evaluates the local rules (and optionally a custom [strategy]).
  /// - If all pass, it delegates to the [TestCell.parent] (if any).
  /// - If a rule returns a `Future`, it waits for it.
  /// - If a rule throws, the validation **fails closed** and returns
  ///   `false` — a throwing integrity gate must never authorize anything.
  ///
  /// ### Parameters:
  /// - [object]: The data, signal, or state change candidate being verified.
  /// - [host]: The [Cell] context (if any) where this validation is occurring.
  /// - [arguments]: Optional metadata, often the [Function] or [Pulse]
  ///   that triggered this request.
  ///
  /// ### Returns:
  /// `true` if the operation is **AUTHORIZED**; `false` if it is **NEUTRALIZED**.
  @override
  FutureOr<bool> call(dynamic object, {covariant C? host, dynamic arguments}) {
    try {
      final result = super.call(object, host: host, arguments: arguments);
      if (result is Future<bool>) {
        // The sync try/catch above cannot see exceptions thrown inside an
        // async rule — the rejection lands in the future. An integrity
        // gate fails CLOSED on a throwing rule, governed host or not.
        return result.catchError((Object e, StackTrace st) {
          if (e is! Exception) return Error.throwWithStackTrace(e, st);
          return false;
        });
      }
      return result;
    } on Exception {
      // Fail closed: a throwing rule must never authorize an operation.
      return false;
    }
  }

  /// Validates the execution of a functional [action] and its associated [arguments]
  /// on the [host] cell, supporting **Hybrid Convergence** (Sync/Async).
  ///
  /// This method serves as the **Behavioral Gatekeeper** for all imperative
  /// operations within the reactive graph. It acts as an **Integrity Gate**
  /// that ensures every action—treated as a first-class system event—satisfies
  /// both argument-level validity and action-level authorization before
  /// state transitions are permitted.
  ///
  /// ### Developer Ergonomics & Human Legibility
  /// Developers typically don't call this directly. The framework invokes it
  /// automatically when [Cell.apply] is called. It can be called manually for
  /// testing:
  ///
  /// ```dart
  /// final policy = TestCell<Cell>((object, {host, arguments, user}) {
  ///   return object is int && object > 0;
  /// });
  ///
  /// final cell = Cell();
  /// final authorized = await policy.action(
  ///   cell.apply,
  ///   host: cell,
  ///   arguments: (positionalArguments: [5], namedArguments: {}),
  /// );
  /// print(authorized); // true or false
  /// ```
  ///

  /// Validates the execution of a functional [action] and its associated [arguments]
  /// on the [host] cell, supporting **Hybrid Convergence** (Sync/Async).
  ///
  /// This method serves as the **Behavioral Gatekeeper** for all imperative
  /// operations within the reactive graph. It acts as an **Integrity Gate**
  /// that ensures every action—treated as a first-class system event—satisfies
  /// both argument-level validity and action-level authorization before
  /// state transitions are permitted.
  ///
  /// ### When to use
  /// You don't call this directly – the framework invokes it automatically
  /// when [Cell.apply] is called. It can be called manually for testing.
  ///
  /// ### How it works
  /// 1. **Argument Validation**: Each positional and named argument is
  ///    individually validated via `call()`.
  /// 2. **Action‑Specific Rules**: Any [TestActionRule]s in the chain are
  ///    evaluated.
  /// 3. **Delegation**: If local rules pass, the [TestCell.parent] is called.
  /// 4. **Short‑Circuit**: If any validation returns `false`, the whole
  ///    action is rejected.
  ///
  /// ### Example
  /// ```dart
  /// final policy = TestCell<Cell>((object, {host, arguments, user}) {
  ///   return object is int && object > 0;
  /// });
  ///
  /// final cell = Cell();
  /// final authorized = await policy.action(
  ///   cell.apply,
  ///   host: cell,
  ///   arguments: (positionalArguments: [5], namedArguments: {}),
  /// );
  /// print(authorized); // true or false
  /// ```
  ///
  /// ### Parameters:
  /// - [action]: The [Function] being requested.
  /// - [host]: The [Cell] on which the action is to be performed.
  /// - [arguments]: A tuple of positional and named arguments.
  ///
  /// ### Returns:
  /// `true` if the action is authorized; `false` otherwise.
  @override
  FutureOr<bool> action(Function action,
      {required C host, Arguments? arguments, ApplyCommand? command}) {
    // Phase A: Argument Integrity
    if (arguments != null) {
      final elements = [
        if (arguments.positionalArguments != null)
          ...arguments.positionalArguments!,
        if (arguments.namedArguments != null)
          ...arguments.namedArguments!.values
      ];

      final argResult = _checkArguments(elements, 0, host, action);

      // If arguments go async, chain the rule check to the future
      if (argResult is Future<bool>) {
        return argResult.then((passed) {
          if (!passed) return false;
          return _checkActionRules(action, host, arguments, command);
        });
      }

      if (!argResult) return false;
    }

    // Phase B: Action Specialization
    return _checkActionRules(action, host, arguments, command);
  }

  /// Internal recursive evaluator for argument integrity that handles FutureOr branching.
  FutureOr<bool> _checkArguments(
      List elements, int index, C host, Function action) {
    for (var i = index; i < elements.length; i++) {
      final result = call(elements[i], host: host, arguments: action);

      if (result is Future<bool>) {
        return result.then((passed) {
          if (!passed) return false;
          return _checkArguments(elements, i + 1, host, action);
        });
      }

      if (!result) return false;
    }
    return true;
  }

  /// Internal evaluator for TestActionRules that handles FutureOr branching and parent delegation.
  FutureOr<bool> _checkActionRules(
      Function action, C host, Arguments? arguments, ApplyCommand? command) {
    // Specialized [TestActionRule]s receive the action (and the surrounding
    // ApplyCommand) through `action(...)`. Every OTHER rule is consulted
    // generically with the action object — mirroring `_checkArguments`,
    // which invokes the full chain for each argument. Without this, the
    // Function-checking branch of a generic rule in a composed policy is
    // silently skipped during action validation.
    final rules = _rules.toList();

    FutureOr<bool> runRules(int index) {
      for (var i = index; i < rules.length; i++) {
        final rule = rules[i];
        // `TestCell` implements every specialized rule interface, so a
        // runtime `is TestActionRule` check cannot tell the two apart.
        // Nested TestCells go through `call` (which evaluates their
        // generic rule with the action object); only true TestActionRule
        // instances use the specialized path.
        final result = rule is TestCell<C>
            ? rule.call(action, host: host, arguments: arguments)
            : rule is TestActionRule<C>
                ? rule.action(action,
                    host: host, arguments: arguments, command: command)
                : rule.call(action, host: host, arguments: arguments);

        if (result is Future<bool>) {
          return result.then((passed) {
            if (!passed) return false;
            return runRules(i + 1);
          });
        }

        if (!result) return false;
      }

      // All local rules passed, delegate to parent
      return _parent?.action(action,
              host: host, arguments: arguments, command: command) ??
          true;
    }

    return runRules(0);
  }

  /// Validates the establishment of a reactive [link] from a candidate [Cell]
  /// to the [host] cell, supporting **Hybrid Convergence** (Sync/Async).
  ///
  /// This method serves as the **Topology Gatekeeper** for the reactive graph.
  /// In the Cell framework, a link is more than a simple reference; it is a
  /// directional synapse through which signals and state changes propagate.
  /// This method ensures that the graph's structure adheres to defined
  /// architectural constraints and security boundaries.
  ///
  /// ### When to use
  /// You don't call this directly – the framework invokes it automatically
  /// when [Synapses.link] is called. It can be called for testing.
  ///
  /// ### How it works
  /// 1. It collects all [TestLinkRule]s in the chain.
  /// 2. Each rule is given the candidate link and the host.
  /// 3. If any rule returns `false`, the link is rejected.
  /// 4. If all pass, it delegates to the [TestCell.parent].
  ///
  /// ### Example
  /// ```dart
  /// // Domain Isolation
  /// final domainPolicy = TestCell<Cell>((object, {host, arguments, user}) {
  ///   if (object is Cell) {
  ///     final targetDomains = object.context.domains ?? '';
  ///     final hostDomains = host?.context.domains ?? '';
  ///     return targetDomains == hostDomains; // Same domain only
  ///   }
  ///   return true;
  /// });
  ///
  /// final cell = Cell(testRule: domainPolicy);
  /// final sameDomain = Cell(context: Context.module('Finance'));
  /// final diffDomain = Cell(context: Context.module('HR'));
  ///
  /// // This link is allowed (same domain)
  /// await cell._nucleus.synapses.link(cell, downstreamCell: sameDomain);
  ///
  /// // This link is blocked (different domain)
  /// await cell._nucleus.synapses.link(cell, downstreamCell: diffDomain);
  /// ```
  ///
  /// ### Parameters:
  /// - [link]: The candidate [Cell] attempting to connect.
  /// - [host]: The target [Cell] to which the link is requested.
  ///
  /// ### Returns:
  /// `true` if the link is permitted; `false` otherwise.
  @override
  FutureOr<bool> link(covariant Cell link, {required C host}) {
    final rules = _rules.whereType<TestLinkRule<C>>().toList();

    FutureOr<bool> runRules(int index) {
      for (var i = index; i < rules.length; i++) {
        final rule = rules[i];
        // Nested TestCells implement TestLinkRule, so dispatch them through
        // `call` — their generic rule must see the link object. Only true
        // TestLinkRule instances use the specialized path.
        final result = rule is TestCell<C>
            ? rule.call(link, host: host)
            : rule.link(link, host: host);

        if (result is Future<bool>) {
          return result.then((passed) {
            if (!passed) return false;
            return runRules(i + 1);
          });
        }

        if (!result) return false;
      }

      // All local link rules passed, delegate to parent
      return _parent?.link(link, host: host) ?? true;
    }

    return runRules(0);
  }

  /// Validates an incoming [pulse] intended for processing by the [host] cell,
  /// supporting **Hybrid Convergence** (Sync/Async).
  ///
  /// This method acts as the **Immunological Barrier** for the reactive graph's
  /// signaling layer. In the Cell framework, signals are the primary vehicle
  /// for state transitions and event propagation. `pulse` ensures that only
  /// authorized, logically sound, and contextually appropriate messages are
  /// allowed to cross a cell's "membrane" and trigger its internal logic.
  ///
  /// ### When to use
  /// You don't call this directly – the framework invokes it automatically
  /// when a [Pulse] arrives at a cell. It can be called for testing.
  ///
  /// ### How it works
  /// 1. It collects all [TestPulseRule]s in the chain.
  /// 2. Each rule is given the pulse and the host.
  /// 3. If any rule returns `false`, the pulse is dropped.
  /// 4. If all pass, it delegates to the [TestCell.parent].
  ///
  /// ### Parameters:
  /// - [pulse]: The incoming [Pulse] to be validated.
  /// - [host]: The target [Cell] that will process the pulse if accepted.
  ///
  /// ### Returns:
  /// `true` if the pulse is permitted to propagate; `false` otherwise.
  @override
  FutureOr<bool> pulse(covariant Pulse pulse, {required C host}) {
    final rules = _rules.whereType<TestPulseRule<C>>().toList();

    FutureOr<bool> runRules(int index) {
      for (var i = index; i < rules.length; i++) {
        final rule = rules[i];
        // Nested TestCells implement TestPulseRule, so dispatch them through
        // `call` — their generic rule must see the pulse object. Only true
        // TestPulseRule instances use the specialized path.
        final result = rule is TestCell<C>
            ? rule.call(pulse, host: host)
            : rule.pulse(pulse, host: host);

        if (result is Future<bool>) {
          return result.then((passed) {
            if (!passed) return false;
            return runRules(i + 1);
          });
        }

        if (!result) return false;
      }

      // All local pulse rules passed, delegate to parent
      return _parent?.pulse(pulse, host: host) ?? true;
    }

    return runRules(0);
  }

  /// Composes this **Integrity Gate** ([TestCell]) with another validation rule
  /// using the **Compositional Algebra** of the framework.
  ///
  /// The `+` operator is the primary architectural utility for building
  /// multi-layered **Validation Pipelines**. It allows developers to treat
  /// validation logic as additive, weaving independent, atomic rules into a
  /// single, cohesive **System Law**.
  ///
  /// ### When to use
  /// Use this to combine multiple rules into a single policy. It's the most
  /// common way to build complex validation chains.
  ///
  /// ### How it works
  /// The operator creates a new [TestCell] that evaluates the `other` rule
  /// first, and if that passes, evaluates `this` rule next (as the parent).
  /// This creates a left‑to‑right chain where all rules must pass.
  ///
  /// ### Example
  /// ```dart
  /// final policy = isPositive + isAuthorized + isInRange;
  /// ```
  ///
  /// ### Parameters:
  /// - [other]: The [TestRule] to be prepended to the current validation stack.
  ///
  /// ### Returns:
  /// A new [TestCell] representing the unified, layered logic of both
  /// contributing policies.
  @override
  TestCell<C> operator +(covariant TestRule<C> other) {
    return TestCell<C>.chain([this, other]);
  }
}

/// A rule that validates incoming [Pulse] signals before they reach a cell.
///
/// Use this to enforce payload schemas, actor permissions, or priority
/// thresholds on pulses.
///
/// ### When to use
/// When you need to filter or authorize pulses based on their content or
/// metadata – e.g., only accept pulses from trusted sources, or ensure
/// payloads meet business constraints.
///
/// ### How it works
/// - The rule is attached to a cell via [TestCell] and evaluated whenever a
///   pulse arrives.
/// - The [rule] function receives the pulse, the host cell, and optional user
///   data.
/// - Return `true` to let the pulse through, `false` to drop it.
///
/// ### Example
/// ```dart
/// final adminOnly = TestPulseRule<Cell>((pulse, {host, ...}) =>
///     pulse.context.actor == 'admin');
/// final highPriority = TestPulseRule<Cell>((pulse, ...) =>
///     pulse.priority >= 50);
/// final pulsePolicy = adminOnly + highPriority;
/// ```
///
/// See also:
/// * [TestCell.pulse] – the method that orchestrates pulse validation.
/// * [TestLinkRule], [TestActionRule] – sibling guards for other operations.
///
/// {@category Testing & Validation}
class TestPulseRule<C extends Cell> extends TestRule<C> {
  /// Creates a pulse validation rule.
  ///
  /// The [rule] function is called for every incoming pulse. Return `true`
  /// to accept the pulse, `false` to reject it.
  ///
  /// ### When to use
  /// Use this to define a custom pulse‑level validation. For more complex
  /// conditions, compose multiple rules.
  ///
  /// ### How it works
  /// The rule is wrapped into a generic [TestRule] that only triggers if
  /// the object is a [Pulse] and the host is non‑null.
  ///
  /// ### Example
  /// ```dart
  /// final rule = TestPulseRule<Cell>((pulse, {host, user}) {
  ///   return pulse.context.actor == 'admin';
  /// });
  ///
  /// final cell = Cell();
  /// final pulse = Pulse.governed<int>(
  ///   context: PulseContext(actor: 'admin'),
  /// );
  ///
  /// // Test the rule
  /// final authorized = await rule.pulse(pulse, host: cell);
  /// print(authorized); // true or false
  ///
  /// final actorRule = TestPulseRule<Cell>((pulse, {host, user}) {
  ///   return pulse.context.actor == 'admin';
  /// });
  ///
  /// final priorityRule = TestPulseRule<Cell>((pulse, {host, user}) {
  ///   return pulse.priority >= 50;
  /// });
  ///
  /// final pulsePolicy = actorRule + priorityRule;
  ///
  /// // Test with valid pulse
  /// final cell = Cell();
  /// final valid = Pulse.governed<int>(
  ///   context: PulseContext(actor: 'admin'),
  ///   priority: 60,
  /// );
  /// expect(await pulsePolicy.pulse(valid, host: cell), isTrue);
  ///
  /// // Test with invalid pulse (wrong actor)
  /// final invalid = Pulse.governed<int>(
  ///   context: PulseContext(actor: 'user'),
  ///   priority: 60,
  /// );
  /// expect(await pulsePolicy.pulse(invalid, host: cell), isFalse);
  /// ```
  ///
  /// ### Parameters:
  /// - [rule]: The validation logic.
  /// - [parent]: An optional parent rule to chain after this one.
  /// - [user]: Optional metadata.
  TestPulseRule(
      bool Function(Pulse pulse, {required C host, dynamic user}) rule,
      {TestPulseRule<C>? super.parent,
      dynamic user})
      : super((dynamic object, {C? host, dynamic arguments, dynamic user}) {
          return host != null && object is Pulse
              ? rule(object, host: host, user: user)
              : true;
        });

  /// Executes the pulse validation logic for a specific reactive [pulse]
  /// targeting the [host] cell, supporting **Hybrid Convergence**.
  ///
  /// This method is the operational heart of the [TestPulseRule]. It bridges
  /// the general-purpose validation mechanism with the specialized
  /// pulse-processing requirements of the reactive graph. It is responsible
  /// for ensuring that a specific message is contextually and structurally
  /// valid before it is allowed to cross the cell's "membrane" and trigger
  /// internal logic or state transitions.
  ///
  /// ### When to use
  /// You don't call this directly – the framework invokes it automatically
  /// when a [Pulse] arrives at a cell. It can be called manually for
  /// testing.
  ///
  /// ### How it works
  /// It delegates to the base `call` method, which handles the actual rule
  /// evaluation and parent delegation.
  ///
  /// ### Parameters:
  /// - [pulse]: The [Pulse] instance being validated.
  /// - [host]: The [Cell] that is the intended destination.
  ///
  /// ### Returns:
  /// `true` if the pulse satisfies the rule; `false` otherwise.
  FutureOr<bool> pulse(covariant Pulse pulse, {required C host}) {
    return call(pulse, host: host);
  }
}

/// A specialized behavioral guard for validating **Topological Synapses** and
/// graph formation within the reactive framework.
///
/// [TestLinkRule] represents the **Structural Gatekeeper** of a [Cell]. It is
/// designed to audit the directional relationships between nodes, governing
/// how cells connect to one another in the global data-flow graph. It extends
/// the base validation architecture to provide type-safe, link-aware constraints.
///
/// ### When to use
/// Use this when you need to enforce rules on which cells can observe each
/// other – e.g., domain isolation, clearance checks, or compliance
/// requirements.
///
/// ### How it works
/// - The rule is attached to a cell via [TestCell] and evaluated whenever a
///   link is attempted.
/// - The [rule] function receives the candidate link cell, the host cell,
///   and optional user data.
/// - Return `true` to allow the link, `false` to block it.
///
/// ### Example
/// ```dart
/// // Only allow linking to cells in the same domain
/// final sameDomainRule = TestLinkRule<Cell>((link, {host, user}) {
///   return link.context.domains == host.context.domains;
/// });
///
/// // Block links to ValueCells (only allow standard Cells)
/// final noValueCellsRule = TestLinkRule<Cell>((link, {host, user}) {
///   return link is! ValueCell;
/// });
///
/// // Allow linking only to cells with 'public' context
/// final publicOnlyRule = TestLinkRule<Cell>((link, {host, user}) {
///   return link.context.domains?.contains('public') ?? false;
/// });
///
/// // Using user data for configuration
/// final allowedDomainsRule = TestLinkRule<Cell>((link, {host, user}) {
///   final allowed = user as List<String>? ?? ['public'];
///   return allowed.any((d) => link.context.domains?.contains(d) ?? false);
/// }, user: ['public', 'internal']);
///
/// // Domain isolation rule
/// final domainRule = TestLinkRule<Cell>((link, {host, user}) {
///   return link.context.domains == host.context.domains;
/// });
///
/// // Security clearance rule
/// final clearanceRule = TestLinkRule<Cell>((link, {host, user}) {
///   final hostClearance = host.context.clearance ?? Clearance.observational;
///   final linkClearance = link.context.clearance ?? Clearance.observational;
///   return linkClearance.index >= hostClearance.index;
/// });
///
/// // Compliance rule
/// final complianceRule = TestLinkRule<Cell>((link, {host, user}) {
///   final hostCompliance = host.context.compliances?.split(',') ?? [];
///   final linkCompliance = link.context.compliances?.split(',') ?? [];
///   return linkCompliance.every((c) => hostCompliance.contains(c));
/// });
///
/// // Compose into a complete link policy
/// final linkPolicy = domainRule + clearanceRule + complianceRule;
///
/// // Use in a cell
/// final cell = Cell(testRule: linkPolicy);
/// ```
///
/// See also:
/// * [TestCell.link] – the orchestrator of this rule.
/// * [TestPulseRule], [TestActionRule] – sibling guards.
///
/// {@category Testing & Validation}
class TestLinkRule<C extends Cell> extends TestRule<C> {
  /// Synthesizes a specialized [TestLinkRule] instance for auditing
  /// **Topological Synapses** and graph formation.
  ///
  /// This constructor initializes a **Structural Guard** that targets the
  /// framework's linking layer. It allows for the definition of high-fidelity,
  /// connection-aware constraints that protect the architectural integrity
  /// of the reactive graph by governing which [Cell] nodes are permitted
  /// to establish dependencies with the [host].
  ///
  /// ### When to use
  /// Use this to define a custom rule for link validation.
  ///
  /// ### How it works
  /// The provided [rule] function is called whenever a link is attempted.
  /// It receives the candidate link, the host cell, and optional user data.
  ///
  /// ### Example
  /// ```dart
  /// final domainRule = TestLinkRule<Cell>((link, {host, user}) {
  ///   return link.context.domains == host.context.domains;
  /// });
  /// ```
  ///
  /// ### Parameters:
  /// - [rule]: The core validation logic.
  /// - [parent]: An optional [TestLinkRule] for policy inheritance.
  /// - [user]: Optional metadata.
  TestLinkRule(bool Function(Cell link, {required C host, dynamic user}) rule,
      {TestLinkRule<C>? super.parent, dynamic user})
      : super((dynamic object, {C? host, dynamic arguments, dynamic user}) {
          return host != null && object is Cell
              ? rule(object, host: host, user: user)
              : true;
        });

  /// Executes the topological validation logic for a candidate [link] attempting
  /// to connect to the [host] cell, supporting **Hybrid Convergence**.
  ///
  /// This method is the operational heart of the [TestLinkRule]. It serves as
  /// the **Synapse Gatekeeper**, determining whether a directional relationship
  /// (dependency) is permitted to form within the reactive graph. It transforms
  /// abstract architectural policies into deterministic runtime boundaries.
  ///
  /// ### When to use
  /// You don't call this directly – the framework invokes it automatically
  /// when [Synapses.link] is called. It can be called manually for testing.
  ///
  /// ### How it works
  /// It delegates to the base `call` method, which evaluates the rule and
  /// parent chain.
  ///
  /// ### Parameters:
  /// - [link]: The candidate [Cell] attempting to establish a dependency.
  /// - [host]: The target [Cell] that would be observed.
  ///
  /// ### Returns:
  /// `true` if the link is permitted; `false` otherwise.
  FutureOr<bool> link(covariant Cell link, {required C host}) {
    return call(link, host: host);
  }
}

/// A specialized behavioral guard for validating imperative logic and
/// functional [action] execution within the reactive graph.
///
/// [TestActionRule] represents the **Transactional Guard** of the ecosystem.
/// While pulse and link rules govern the passive flow of data and topology,
/// [TestActionRule] governs the active, imperative side of the system. It
/// provides a rigorous security and integrity audit for any function-based
/// operation attempted on or through a [Cell].
///
/// ### When to use
/// Use this when you need to restrict which functions can be invoked on a
/// cell – e.g., only allow read operations, validate arguments, or enforce
/// rate limiting.
///
/// ### How it works
/// - The rule is attached to a cell via [TestCell] and evaluated whenever
///   [Cell.apply] is called.
/// - The [rule] function receives the action (a [Function]), the host cell,
///   the arguments (positional and named), and optional user data.
/// - Return `true` to allow the action, `false` to block it.
///
/// ### Example
/// ```dart
/// // Complete Action Validation Pipeline
/// // 1. Authorize action type
/// final actionRule = TestActionRule<Cell>((action, {host, arguments, user}) {
///   final name = action.toString();
///   return name.contains('read') || name.contains('write');
/// });
///
/// // 2. Validate user context
/// final contextRule = TestActionRule<Cell>((action, {host, arguments, user}) {
///   final ctx = host.context;
///   return ctx.stakeholders?.contains('Admin') ?? false;
/// });
///
/// // 3. Validate arguments
/// final argRule = TestActionRule<Cell>((action, {host, arguments, user}) {
///   final args = arguments?.positionalArguments;
///   if (args != null && args.isNotEmpty) {
///     return args.first is int && (args.first as int) > 0;
///   }
///   return true;
/// });
///
/// // 4. Rate limiting
/// final rateLimitRule = TestActionRule<Cell>((action, {host, arguments, user}) {
///   // Check if action has been called too many times
///   return (host as MyCell).actionCount < 100;
/// });
///
/// // Compose into a complete action policy
/// final actionPolicy = actionRule + contextRule + argRule + rateLimitRule;
///
/// // Use in a cell
/// final cell = Cell(testRule: actionPolicy);
///
/// // This action will be validated by all rules
/// final result = cell.apply((int x) => x * 2, [5]);
/// // Only executed if all rules pass
/// ```
///
/// See also:
/// * [TestCell.action] – the orchestrator of this rule.
/// * [TestPulseRule], [TestLinkRule] – sibling guards.
///
/// {@category Testing & Validation}
class TestActionRule<C extends Cell> extends TestRule<C> {
  /// Synthesizes a specialized [TestActionRule] instance for auditing
  /// **Imperative Logic** and functional executions.
  ///
  /// This constructor initializes a **Transactional Guard** that targets the
  /// framework's action layer. It allows for the definition of precise,
  /// imperative-aware constraints that protect a [Cell] from unauthorized
  /// state mutations, illegal function calls, or malformed argument payloads.
  ///
  /// ### When to use
  /// Use this to define a custom rule for function execution validation.
  ///
  /// ### How it works
  /// The provided [rule] function is called whenever [Cell.apply] is invoked.
  /// It receives the action, the host, the arguments, and optional user data.
  ///
  /// ### Example
  /// ```dart
  /// final actionRule = TestActionRule<Cell>((action, {host, arguments, user}) {
  ///   return action.toString().contains('read');
  /// });
  /// ```
  ///
  /// ### Parameters:
  /// - [rule]: The core validation logic.
  /// - [parent]: An optional [TestActionRule] for policy inheritance.
  /// - [user]: Optional metadata.
  TestActionRule(
      bool Function(Function action,
              {required C host, Arguments? arguments, dynamic user})
          rule,
      {super.parent,
      dynamic user})
      : super((dynamic object, {C? host, dynamic arguments, dynamic user}) {
          return host != null && object is Function
              ? rule(object as Function,
                  host: host,
                  arguments: arguments is Arguments ? arguments : null,
                  user: user)
              : true;
        });

  /// Validates the execution of a functional [action] and its associated
  /// [arguments] on the [host] cell, supporting **Hybrid Convergence**.
  ///
  /// This method is the operational heart of the [TestActionRule]. It serves as
  /// the **Transactional Guard** for the reactive graph, ensuring that
  /// imperative operations—treated as first-class system events—satisfy
  /// defined security, integrity, and business invariants before being
  /// permitted to modify state.
  ///
  /// ### When to use
  /// You don't call this directly – the framework invokes it automatically
  /// when [Cell.apply] is called. It can be called manually for testing.
  ///
  /// ### How it works
  /// It delegates to the base `call` method, which evaluates the rule and
  /// parent chain.
  ///
  /// ### Parameters:
  /// - [action]: The [Function] being requested.
  /// - [host]: The [Cell] on which the action is to be performed.
  /// - [arguments]: A tuple of positional and named arguments.
  ///
  /// ### Returns:
  /// `true` if the action is authorized; `false` otherwise.
  FutureOr<bool> action(Function action,
      {required C host, Arguments? arguments, ApplyCommand? command}) {
    return call(action, host: host, arguments: arguments);
  }
}
