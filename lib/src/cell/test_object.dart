// Copyright (c) 2025 Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

part of '../../cell.dart';

/// A typedef representing the base implementation class for [TestObject].
///
/// This serves as an implementation detail to allow extending classes to reference
/// the concrete base implementation while maintaining the interface contract through
/// [TestObject].
///
/// ## Usage Context:
/// Used internally when you need to:
/// - Extend the base test object functionality
/// - Maintain the public [TestObject] interface
/// - Access concrete implementation members
///
/// ## Example:
/// ```dart
/// class CustomTestObject<C extends Cell> extends TestObjectBase<C> {
///   // Can access _TestObject implementation details
/// }
/// ```
///
/// See also:
/// - [TestObject] for the public interface
typedef TestObjectBase<C extends Cell> = _TestObject<C>;

/// TestObject is a composite of multiple TestRules that applies them sequentially
/// to validate operations on a Cell.
///
/// Can check signals, links, elements and actions according to multiple
/// test rules that can be combined.
///
/// Types of Rules
///
///   TestActionRule: Controls function execution.
///
///   TestSignalRule: Determines whether a Signal is processed.
///
///   TestLinkRule: Validates link establishment between Cell instances.
///
///   TestElementRule: Determines whether an element is allowed to be processed.
///
/// Example:
/// ```dart
///
/// // Combine rules
/// TestObject.fromRules(rules: [rule1, rule2]);
///
/// // Or use operator +
/// final compositeRule = rule1 + rule2;
///
/// final test = TestObject<Cell>.fromRules(rules: [
///   TestSignalRule(rule: (signal) => signal != null),
///   TestLinkRule(rule: (link) => link is ValidCell)
/// ]);
///
///
///
/// ```
abstract interface class TestObject<C extends Cell> implements TestObjectRule<C>, Iterable<TestRule> {

  /// Default test that always passes
  static const passed = TestObjectTrue();

  /// Creates a TestObject from multiple rules
  const factory TestObject.fromRules({required Iterable<TestRule> rules}) = _TestObject<C>;

  /// Validates a generic object against test rules
  @override
  bool call(Object? object, {covariant C? cell, arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed});

  /// Validates an action against test rules
  bool action(Function action, C cell, {Arguments? arguments});

  /// Validates a signal against test rules
  bool signal(Signal signal, {C? cell});

  /// Validates a cell link against test rules
  bool link(Cell link, {C? cell});

}

class _TestObject<C extends Cell> extends IterableBase<TestRule> implements TestObject<C> {

  final Iterable<TestRule> _rules;

  const _TestObject({required Iterable<TestRule> rules})
      : _rules = rules;


  @override
  bool call(Object? object, {covariant C? cell, arguments, bool Function(TestRule rule, Exception e) exception = TestRuleTrue.passed}) {
    final checked = Set<TestRule>.identity();

    bool process(TestRule rule) {
      if (rule is TestObject<C>) {
        for (var r in rule) {
          if (process(r) == false) {
            return false;
          }
        }
      }

      if (checked.add(rule)) {
        try {
          if (rule(object, cell: cell, arguments: arguments) == false) {
            return false;
          }
        } on Exception catch(e) {
          if (exception(rule, e) == false) {
            return false;
          }
        }
      }
      return true;
    }
    return process(this);
  }



  @override
  bool action(Function action, covariant C cell, {Arguments? arguments}) {
    if (cell is Unmodifiable && cell.modifiable.contains(action)) {
      return false;
    }

    final checked = Set<TestRule>.identity();

    bool process(TestRule rule) {
      if (rule is TestObject<C>) {
        for (var r in rule) {
          if (process(r) == false) {
            return false;
          }
        }
      }

      if (rule is TestActionRule<C> && checked.add(rule)) {
        try {
          if (rule.action(action, cell, arguments: arguments) == false) {
            return false;
          }
        } catch(_) {}
      }
      return true;
    }
    return process(this);

  }

  @override
  bool signal(Signal signal, {C? cell}) {

    final checked = Set<TestRule>.identity();

    bool process(TestRule rule) {
      if (rule is TestObject<C>) {
        for (var r in rule) {
          if (process(r) == false) {
            return false;
          }
        }
      }

      if (rule is TestSignalRule<C> && checked.add(rule)) {
        try {
          if (rule.signal(signal, cell: cell) == false) {
            return false;
          }
        } catch(_) {}
      }
      return true;
    }
    return process(this);
  }

  @override
  bool link(Cell link, {C? cell}) {

    final checked = Set<TestRule>.identity();

    bool process(TestRule rule) {
      if (rule is TestObject<C>) {
        for (var r in rule) {
          if (process(r) == false) {
            return false;
          }
        }
      }

      if (rule is TestLinkRule<C> && checked.add(rule)) {
        try {
          if (rule.link(link, cell: cell) == false) {
            return false;
          }
        } catch(_) {}
      }
      return true;
    }
    return process(this);
  }

  @override
  TestObject<C> operator +(TestRule other) {
    return TestObject<C>.fromRules(rules: [other, this]);
  }

  @override
  Iterator<TestRule> get iterator => _rules.iterator;

}

/// A default implementation of [TestObject] that always passes validation.
///
/// This serves as:
/// - A neutral element in rule composition (acts as identity for `+` operator)
/// - A default "allow all" testing strategy
/// - A base case for rule processing
///
/// Example usage:
/// ```dart
/// const alwaysPass = TestObjectTrue();
///
/// // In cell configuration:
/// Cell(
///   test: alwaysPass,  // Will allow all operations
///   // ...
/// );
///
/// // In rule composition:
/// final composite = alwaysPass + otherRule; // Equivalent to just otherRule
/// ```
class TestObjectTrue extends IterableBase<TestRule> implements TestObject {

  /// The singleton const instance of the always-true test object.
  const TestObjectTrue();

  @override
  TestObject<Cell> operator +(TestRule other) => this;

  @override
  bool action(Function action, Cell host, {Arguments? arguments}) => true;

  @override
  bool call(Object? object, {Cell? cell, arguments, bool Function(TestRule rule, Exception e)? exception}) => true;

  @override
  Iterator<TestRule> get iterator => Iterable<TestRule>.empty().iterator;

  @override
  bool signal(Signal signal, {Cell? cell}) => true;

  @override
  bool link(Cell link, {Cell? cell}) => true;

}
