// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../collective.dart';

/// Base type for Collective test rules
typedef TestCollectiveBase<E, C extends Collective<E>> = TestCollective<E,C>;

/// Function signature for validating elements in a Collective
/// Parameters:
/// - element: The element being validated
/// - base: The Collective containing the element
/// - action: The modifying action being performed (optional)
/// - user: Optional user context
typedef TestCollectiveElementType<E,C extends Collective<E>> = bool Function(E? element, C base, {Function? action, dynamic user});


/// A rule-based testing system for validating operations on [Collective] collections.
///
/// This class extends [TestObject] to provide specialized validation rules for
/// collection operations, including element validation, action restrictions,
/// and size limitations. It allows for complex validation logic to be composed
/// from simple rule functions.
///
/// Rules can be combined using the `+` operator to create composite validations.
///
/// Type parameters:
/// - [E]: The type of elements in the collection
/// - [C]: The specific type of Collective being tested
///
/// @param elementDisallow: Tests if elements can be added
/// @param actionDisallow: Tests if actions are allowed
/// @param maxLength: Maximum collection size
///
/// Example:
/// ```dart
/// // Create reactive list with validation
/// final todos = CollectiveList<String>(
///     ['Task 1', 'Task 2'],
///     test: TestCollective.create(
///         maxLength: 5,
///         elementDisallow: (task, _) => task.isEmpty
///     )
/// );
///
/// // Add valid item
/// todos.add('Task 3'); // Allowed
///
/// // Try invalid add
/// todos.add(''); // Throws - empty task not allowed
/// ```
///
/// Example:
/// ```dart
/// final safeList = CollectiveList<int>(
///   [],
///   test: TestCollective.create(
///     elementDisallow: (num, _) => num < 0, // No negatives
///     actionDisallow: (_) => [List.clear], // Don't allow clear
///     maxLength: 100
///   )
/// );
/// ```
class TestCollective<E, C extends Collective<E>> extends TestObjectBase<C> {

  /// Maximum size constant
  static const asBigAsDartAllows = -1;

  /// A test that always passes all validations.
  static const passed = TestCollectiveTrue();

  /// Creates validation rules for Collectives
  const TestCollective({required super.rules}) : super();

  /// Factory constructor for creating a [TestCollective] with common validation scenarios.
  ///
  /// Parameters:
  /// - [elementDisallow]: Optional function to reject specific elements
  /// - [actionDisallow]: Optional function to reject specific actions
  /// - [maxLength]: Maximum allowed collection size (use [asBigAsDartAllows] for no limit)
  factory TestCollective.create({
    bool Function(E? e, C collective)? elementDisallow,
    Iterable<Function> Function<C>(C collective)? actionDisallow,
    int maxLength = TestCollective.asBigAsDartAllows
  }) {

    final rules = <TestRule>[];

    if (elementDisallow != null) {
      elementRule(element, base, {action, user}) {
        return elementDisallow(element, base) ? true : false;
      }
      final rule = TestCollectiveElementRule<E,C>(rule: elementRule);
      rules.add(rule);
    }

    if (actionDisallow != null) {
      actionRuleFunc(action, base, {arguments, user}) {
        return actionDisallow(base).contains(action) ? true : false;
      }
      final rule = TestActionRule<C>(rule: actionRuleFunc);
      rules.add(rule);
    }

    if (maxLength != TestCollective.asBigAsDartAllows) {
      actionRuleFunc(Function action, C collective, {Arguments? arguments, user}) {
        if (collective is Set) {
          final modifiable = <Function>[(collective as Set).add, (collective as Set).addAll];
          return modifiable.contains(action) && collective.length >= maxLength ? true : false;
        } else if (collective is List) {
          final list = collective as List;
          final modifiable = <Function>[list.add, list.addAll, list.insert, list.insertAll];
          return modifiable.contains(action) && collective.length >= maxLength ? true : false;
        } else if (collective is Queue) {
          final modifiable = <Function>[(collective as Queue).add, (collective as Queue).addAll];
          return modifiable.contains(action) && collective.length >= maxLength ? true : false;
        }
        return false;
      }
      final rule = TestActionRule<C>(rule: actionRuleFunc);
      rules.add(rule);
    }

    if (rules.isNotEmpty) {
      return TestCollective<E,C>(rules: rules);
    }

    return const TestCollectiveTrue();
  }

  /// Validates an operation on the collective.
  ///
  /// Parameters:
  /// - [object]: The object being validated (either an element or action)
  /// - [cell]: The collective being operated on
  /// - [arguments]: Additional arguments for the operation
  /// - [exception]: Exception handler for validation failures
  ///
  /// Returns true if the operation is allowed, false otherwise.
  @override
  bool call(object, {covariant C? cell, arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed}) {

    try {
      if (cell != null && object is E && (arguments == null || arguments is Function)) {
        return element(object, cell, action: arguments);
      }
      return super.call(object, cell: cell, arguments: arguments, exception: exception);
    } on Exception catch(e) {
      if (exception(this, e) == false) {
        return false;
      }
    }

    return true;
  }

  /// Validates whether a specific element can be added to the collective.
  ///
  /// Parameters:
  /// - [element]: The element to validate
  /// - [collective]: The target collective
  /// - [action]: Optional action context for the validation
  ///
  /// Returns true if the element is allowed, false otherwise.
  bool element(E element, C collective, {Function? action}) {

    final tested = Set<TestObject>.identity();

    bool process(TestObject obj) {
      if (tested.add(obj)) {
        for (var e in obj) {
          if (e is TestCollectiveElementRule<E,C>) {
            try {
              if (e.element(element, collective, action: action) == false) {
                return false;
              }
            } on Exception catch(_) {}
          }
          else if (e is TestObject) {
            return process(e);
          }
        }
      }
      return true;
    }

    return process(this);
  }

}

/// A rule implementation for validating elements in a [Collective].
///
/// Wraps a validation function that determines whether a specific element
/// is allowed in a collective.
class TestCollectiveElementRule<E, C extends Collective<E>> extends TestObjectRuleBase<C> {

  final TestCollectiveElementType<E,C> _rule;
  final dynamic _user;

  /// Creates an element validation rule.
  TestCollectiveElementRule({required TestCollectiveElementType<E,C> super.rule, super.user})
      : _rule = rule, _user = user, super();

  @override
  bool call(object, {covariant C? cell, arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed}) {
    try {
      if (object is E && cell != null && (arguments == null || arguments is Function)) {
        return element(object, cell, action: arguments);
      }
    } catch(_) {}
    return true;
  }

  /// Validates an element against this rule.
  bool element(E? element, covariant C collective, {Function? action}) {
    try {
      return _rule(element, collective, action: action, user: _user);
    } catch(_) {}
    return true;
  }

}

/// A [TestCollective] implementation that always passes all validations.
class TestCollectiveTrue<E, C extends Collective<E>> extends IterableBase<TestRule> implements TestCollective<E,C> {

  /// A test that always passes all validations.
  const TestCollectiveTrue();

  @override
  bool action(Function action, Collective<E> base, {Arguments? arguments}) {
    return true;
  }

  @override
  bool call(object, {Collective<E>? cell, arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed}) {
    return true;
  }

  @override
  bool element(E element, Collective<E> base, {Function? action}) {
    return true;
  }

  @override
  Iterator<TestRule> get iterator => const Iterable<TestRule>.empty().iterator;

  @override
  TestCollective<E,C> operator +(TestRule other) {
    return TestCollective<E,C>(rules: [other, this]);
  }

  @override
  bool signal(Signal signal, {C? cell, Arguments? arguments}) => true;

  @override
  bool link(Cell link, {C? cell}) => true;

}

