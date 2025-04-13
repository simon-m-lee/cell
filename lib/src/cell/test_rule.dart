// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell.dart';

/// Represents a tuple of positional and named arguments for function calls.
/// Used when validating or processing function applications in cells.
///
/// Contains:
/// - positionalArguments: List of positional arguments
/// - namedArguments: Map of named arguments (using Symbols as keys)
typedef Arguments = ({List? positionalArguments, Map<Symbol, dynamic>? namedArguments});

/// Function signature for validating actions performed on cells.
///
/// Parameters:
/// - action: The function being validated
/// - cell: The cell receiving the action
/// - arguments: Optional arguments being passed
/// - user: Optional user context
///
/// Returns true if the action is allowed, false otherwise
typedef TestActionRuleType<C extends Cell> = bool Function(Function action, C cell, {Arguments? arguments, dynamic user});

/// Function signature for validating signals received by cells.
///
/// Parameters:
/// - signal: The incoming signal
/// - cell: The cell receiving the signal (optional)
/// - user: Optional user context
///
/// Returns true if the signal is valid, false otherwise
typedef TestSignalRuleType<C extends Cell> = bool Function(Signal signal, {C? cell, dynamic user});

/// Function signature for validating links between cells.
///
/// Parameters:
/// - link: The cell being linked
/// - cell: The host cell (optional)
/// - user: Optional user context
///
/// Returns true if the link is allowed, false otherwise
typedef TestLinkRuleType<C extends Cell> = bool Function(Cell link, {C? cell, dynamic user});

/// An interface for defining validation rules that can be applied to objects in a reactive cell system.
///
/// TestRules encapsulate validation logic that determines whether operations should be allowed
/// on cells and their contents. Rules can be combined to create complex validation scenarios.
///
/// Rules are used throughout the cell system to:
/// - Validate signal propagation
/// - Authorize cell modifications
/// - Control element operations in collectives
/// - Enforce business logic constraints
///
/// Implementations should override the `call()` method to provide validation logic.
///
/// Example:
/// ```dart
/// class PositiveNumberRule implements TestRule<num, MyCell> {
///   const PositiveNumberRule();
///
///   @override
///   bool call(num object, {MyCell? cell, dynamic arguments}) {
///     return object > 0;
///   }
/// }
/// ```
/// Example usage:
/// ```dart
/// const myRule = TestRuleTrue(); // Default always-true rule
/// final combined = myRule + otherRule; // Rule composition
/// final isValid = myRule(someObject, cell: contextCell);
/// ```
///
/// Type parameters:
/// - [O]: The type of objects this rule validates
/// - [C]: The type of cell this rule operates with (must extend [Cell])
abstract interface class TestRule<O, C extends Cell> {

  const TestRule();

  /// Executes the rule's validation logic.
  ///
  /// Parameters:
  /// - [object]: The object being validated
  /// - [cell]: Optional cell context for the validation
  /// - [arguments]: Additional operation arguments
  /// - [exception]: Handler for any exceptions during validation
  ///
  /// Returns true if validation passes, false if validation fails.
  bool call(O object, {C? cell, dynamic arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed});

  /// Combines this rule with another rule to create a composite validation.
  ///
  /// The resulting [TestObject] will evaluate both rules sequentially,
  /// returning `false` if either rule fails.
  ///
  /// Example:
  /// ```dart
  /// final composite = rule1 + rule2; // Both rules must pass
  /// ```
  TestObject<C> operator +(TestRule other);

}

/// A concrete implementation of [TestRule] that always returns true.
///
/// This serves as:
/// 1. A default "pass-through" rule
/// 2. A base case for rule composition
/// 3. An exception handler default
class TestRuleTrue implements TestRule {

  /// Default exception handler that always returns true (allows the operation).
  static bool passed(TestRule rule, Exception e) => true;

  /// Creates a rule that always passes.
  const TestRuleTrue();

  @override
  TestObject operator +(TestRule other) => const TestObjectTrue();

  /// Executes the rule validation against an object in a cell context.
  ///
  /// Parameters:
  ///   - [object]: The object to validate
  ///   - [cell]: Optional cell context for the validation
  ///   - [arguments]: Additional arguments needed for validation
  ///   - [exception]: Exception handler callback when validation fails
  ///
  /// Returns `true` if validation passes, `false` otherwise.
  ///
  /// Implementations should:
  /// 1. Validate the object against the rule's criteria
  /// 2. Use the exception handler for any validation errors
  /// 3. Return the validation result
  @override
  bool call(object, {Cell? cell, arguments, bool Function(TestRule<dynamic, Cell> rule, Exception e) exception = TestRuleTrue.passed}) => true;
}

/// An abstract interface for creating test rules that validate arbitrary objects
/// within a [Cell] context.
///
/// This serves as the base interface for rules that validate objects of any type,
/// providing factory constructors for common rule creation patterns. It combines
/// the functionality of [TestRule] with additional convenience methods for rule
/// composition and function-based validation.
///
/// Implementations should handle:
/// - Validation of objects against custom criteria
/// - Exception handling during validation
/// - Composition with other rules
/// - Conversion from function-based validators
///
/// Example usage:
/// ```dart
/// // Create from single function
/// final rule1 = TestObjectRule(rule: (obj) => obj.isValid);
///
/// // Create from multiple functions
/// final rule2 = TestObjectRule.fromRules(
///   functions: [check1, check2],
///   user: context
/// );
/// ```
abstract interface class TestObjectRule<C extends Cell> implements TestRule<dynamic,C> {

  factory TestObjectRule({required Function rule, dynamic user}) = _TestObjectRuleView;

  factory TestObjectRule.fromRules({required Iterable<Function> functions, dynamic user}) {
    final rules = functions.map<TestRule>((f) => TestObjectRule(rule: f, user: user));
    return TestObject<C>.fromRules(rules: rules);
  }

}

/// Typedef for the base implementation class.
///
/// Allows extending classes to reference the concrete base implementation
/// while maintaining the interface contract.
typedef TestObjectRuleBase<C extends Cell> = _TestObjectRuleView<C>;

class _TestObjectRuleView<C extends Cell> implements TestObjectRule<C> {

  final dynamic _input, _user;

  _TestObjectRuleView({required Function rule, dynamic user}) : _input = TypeObject<Function>(rule), _user = user;

  @override
  bool call(object, {C? cell, arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed}) {
    try {
      final Function func = _input is TypeObject<Function> ? _input.obj : _input();
      return func(object, systemDecide: cell, arguments: arguments, user: _user);
    } on Exception catch(e) {
      return exception(this, e);
    }
  }

  @override
  TestObject<C> operator +(TestRule other) {
    return TestObject<C>.fromRules(rules: [other, this]);
  }

}

/// A specialized [TestRule] implementation for validating [Signal] objects within a cellular architecture.
///
/// This rule provides signal-specific validation logic to determine whether a signal should be processed
/// by a cell's receptor. It extends the base test rule functionality with signal-specific validation.
///
/// Key characteristics:
/// - Validates only [Signal] objects (throws [ArgumentError] for other types)
/// - Integrates with cell test infrastructure
/// - Supports user context for validation decisions
/// - Composable with other test rules
///
/// Example:
/// ```dart
/// // Create a test that only allows even numbers
/// final evenTest = TestObject<Cell>.fromRules(rules: [
///  TestSignalRule<int>(rule: (signal) => signal.body?.isEven ?? false)
/// ]);
///
/// // Apply test to a cell
/// final restrictedCell = Cell(test: evenTest);
/// ```
///
/// See also:
/// - [TestRule] for the base rule interface
/// - [TestObject] for rule composition
/// - [Receptor] for how signals are processed
class TestSignalRule<C extends Cell> extends _TestObjectRuleView<C> {

  /// Creates a signal validation rule with the given validation logic.
  ///
  /// Parameters:
  ///   - [rule]: The validation function that receives the signal and returns a boolean
  ///     - Signature: `bool Function(Signal signal, {C? cell, dynamic user})`
  ///   - [user]: Optional context object passed to the validation function
  ///
  /// The rule will automatically handle type checking and exception cases.
  TestSignalRule({required TestSignalRuleType<C> super.rule, super.user}) : super();

  /// Validates a potential signal object against this rule.
  ///
  /// Overrides the base implementation to provide signal-specific validation:
  /// 1. Type checks that the object is a [Signal]
  /// 2. Delegates to the concrete validation function
  /// 3. Handles any validation errors
  ///
  /// Parameters:
  ///   - [object]: The object to validate (must be a [Signal])
  ///   - [cell]: The cell context for validation (optional)
  ///   - [arguments]: Not used in signal validation
  ///   - [exception]: Exception handler callback (defaults to passing all exceptions)
  ///
  /// Returns:
  ///   - `true` if the object is a valid signal and passes validation
  ///   - `false` if validation fails
  ///
  /// Throws:
  ///   - [ArgumentError] if the object is not a [Signal]
  @override
  bool call(Object? object, {C? cell, arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed}) {
    try {
      if (object is! Signal) {
        throw ArgumentError.value(object, 'object', 'object not Signal');
      }
      return signal(object, cell: cell);
    } on Exception catch(e) {
      return exception(this, e);
    }
  }

  /// Core signal validation logic.
  ///
  /// Applies the configured validation function to the signal in the optional cell context.
  ///
  /// Parameters:
  ///   - [signal]: The signal to validate
  ///   - [cell]: The cell context (optional)
  ///
  /// Returns whether the signal passes validation.
  bool signal(Signal signal, {C? cell}) {
    final Function func = _input is TypeObject<Function> ? _input.obj : _input();
    return func(signal, cell: cell, user: _user);
  }

}

/// A specialized test rule for validating cell linking operations within a [Cell] context.
///
/// The rule will throw an [ArgumentError] if the tested object is not a [Cell].
class TestLinkRule<C extends Cell> extends _TestObjectRuleView<C> {

  /// Creates a [TestLinkRule] with the given validation function and optional user context.
  ///
  /// Parameters:
  /// - [rule]: The validation function that takes a [Cell] link and returns a [bool]
  /// - [user]: Optional context object passed to the validation function
  TestLinkRule({required TestSignalRuleType<C> super.rule, super.user}) : super();

  /// Validates the given object against this rule.
  ///
  /// Throws an [ArgumentError] if the object is not a [Cell].
  /// Returns the result of applying the rule's validation function to the cell link.
  ///
  /// Parameters:
  /// - [object]: The object to validate (must be a [Cell])
  /// - [cell]: Optional [Cell] context for the validation (typically the host cell)
  /// - [arguments]: Not used in this implementation
  /// - [exception]: Exception handler callback
  @override
  bool call(Object? object, {C? cell, arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed}) {
    try {
      if (object is! Cell) {
        throw ArgumentError.value(object, 'object', 'object not Cell');
      }
      return link(object, cell: cell);
    } on Exception catch(e) {
      return exception(this, e);
    }
  }

  /// Applies the validation rule to a specific cell link.
  ///
  /// Parameters:
  /// - [link]: The cell to validate for linking/unlinking
  /// - [cell]: Optional [Cell] context for the validation (typically the host cell)
  bool link(Cell link, {C? cell}) {
    final Function func = _input is TypeObject<Function> ? _input.obj : _input();
    return func(link, cell: cell, user: _user);
  }

}

/// A specialized test rule for validating function actions within a [Cell] context.
///
/// Throws [ArgumentError] if:
/// - The object is not a [Function]
/// - The host cell is null
/// - The arguments are not of type [Arguments]
class TestActionRule<C extends Cell> extends _TestObjectRuleView<C> {

  /// Creates a [TestActionRule] with the given validation function and optional user context.
  ///
  /// Parameters:
  /// - [rule]: The validation function that takes an action [Function] and returns a [bool]
  /// - [user]: Optional context object passed to the validation function
  TestActionRule({required TestActionRuleType<C> super.rule, super.user}) : super();

  /// Validates the given action against this rule.
  ///
  /// Automatically returns false if:
  /// - The host is unmodifiable and the action is in its modifiable set
  ///
  /// Throws [ArgumentError] if:
  /// - [object] is not a [Function]
  /// - [cell] is null
  /// - [arguments] is not of type [Arguments]
  ///
  /// Parameters:
  /// - [object]: The action to validate (must be a [Function])
  /// - [cell]: The host [Cell] where the action will execute (required)
  /// - [arguments]: The function arguments (must be of type [Arguments])
  /// - [exception]: Exception handler callback
  @override
  bool call(Object? object, {C? cell, arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed}) {
    try {
      if (object is! Function) {
        throw ArgumentError.value(object, 'object', 'object not Function');
      } else if (cell == null) {
        throw ArgumentError.value(cell, 'host', 'host is null');
      } else if (arguments is! Arguments) {
        throw ArgumentError.value(arguments, 'arguments', 'arguments is not Arguments type');
      }
      return action(object, cell, arguments: arguments);
    } on Exception catch(e) {
      return exception(this, e);
    }
  }

  /// Applies the validation rule to a specific action.
  ///
  /// First checks if the host is unmodifiable and contains the action in its modifiable set.
  /// Then applies the rule's validation function if those checks pass.
  ///
  /// Parameters:
  /// - [action]: The function to validate
  /// - [host]: The cell where the action will execute
  /// - [arguments]: The function call arguments
  bool action(Function action, C host, {Arguments? arguments}) {
    if (host is Unmodifiable && host.modifiable.contains(action)) {
      return false;
    }
    final Function func = _input is TypeObject<Function> ? _input.obj : _input();
    return func(action, host, arguments: arguments, user: _user);
  }

}

/// Exception thrown when incompatible rules are combined.
///
/// This indicates a logical inconsistency in the rule composition that
/// would make validation impossible.
class TestRuleIncompatibleException implements Exception {

  /// The exception message
  final dynamic message;

  /// Creates an exception with an optional message
  TestRuleIncompatibleException([this.message]);

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "Exception";
    return "Exception: $message";
  }
}