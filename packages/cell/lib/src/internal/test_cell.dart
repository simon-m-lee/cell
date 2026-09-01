// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A sentinel implementation of [TestCell] that always authorises every operation.
///
/// This is the framework's default "allow‑all" policy, used when you don't
/// specify a custom rule. It provides zero‑overhead validation – every call
/// returns `true` instantly, with no metadata inspection or context checks.
///
/// ### Where to start
/// You never need to construct this directly. It's exposed as the constant
/// [TestCell.allowAll] – the default for every cell:
/// ```dart
/// final cell = Cell(); // testRule defaults to TestCell.allowAll
/// ```
///
/// ### When to use
/// Use [TestCell.allowAll] (or this class) when you have no security or
/// integrity constraints. It's the fastest possible policy because it
/// short‑circuits all validation with a constant `true`.
///
/// ### How it works
/// - It implements all four validation hooks (`call`, `action`, `link`, `pulse`)
///   to unconditionally return `true`.
/// - It is a `const` singleton – every cell that uses `allowAll` points to
///   the exact same instance, saving memory.
/// - When composed with other rules via `+`, it acts as a **compositional
///   identity** – the other rule's logic is preserved, and this rule is
///   effectively a no‑op in the chain.
///
/// ### Non‑obvious
/// - Because it implements `TestCell<Never>`, it is host‑agnostic and can be
///   assigned to any cell type without type variance issues.
/// - When used with `+`, the operator wraps the other rule into a new
///   [TestCell] that delegates to it, ensuring that `allowAll + customRule`
///   behaves exactly like `customRule` alone.
/// - It does not participate in exception handling – since it never throws,
///   it doesn't affect the governed/ungoverned exception rules.
///
/// ### Example
/// ```dart
/// // Default policy – no restrictions
/// final cell = Cell();
/// print(cell.validate is TestPasses); // true
///
/// // Composition – allowAll has no effect
/// final policy = TestCell.allowAll + TestCell<int>((v) => v > 0);
/// // Equivalent to just the positive rule.
/// ```
///
/// See also:
/// * [TestCell.allowAll] – the canonical constant.
/// * [TestCell.readOnly] – the opposite, blocking all mutations.
class TestPasses extends TestCell<Never> {

  /// Creates a constant, immutable instance of the permissive rule.
  ///
  /// This constructor is typically used internally to define [TestCell.allowAll].
  ///
  /// Must extend [TestCell]: [TestRule] is a separate library, so an
  /// `implements` sentinel cannot provide [TestRule]'s private `_record`.
  const TestPasses() : super.fromRecord(());

  @override
  FutureOr<bool> call(object, {covariant Cell? host, arguments}) => true;

  @override
  FutureOr<bool> action(Function action, {required Cell host, Arguments? arguments}) {
    final elements = [
      if (arguments?.positionalArguments != null) ...arguments!.positionalArguments!,
      if (arguments?.namedArguments != null) ...arguments!.namedArguments!.values,
    ];
    _checkArguments(elements, 0, host, action);
    return _checkActionRules(action, host, arguments);
  }

  @override
  FutureOr<bool> link(covariant Cell link, {required Cell host}) => true;

  @override
  FutureOr<bool> pulse(covariant Pulse pulse, {required Cell host}) => true;

  @override
  TestCell<Never> operator +(covariant TestRule<Cell> other) {
    return TestCell((object, {Cell? host, dynamic arguments, dynamic user}) {
      return other.call(object, host: host, arguments: arguments);
    });
  }

  @override
  FutureOr<bool> _checkActionRules(Function action, Cell host, Arguments? arguments) {
    return true;
  }

  @override
  FutureOr<bool> _checkArguments(List<dynamic> elements, int index, Cell host, Function action) {
    return true;
  }

}

class _TestCellReadOnly extends TestCell<Never> {

  const _TestCellReadOnly() : super.fromRecord(());

  @override
  TestCell<Never> operator +(covariant TestRule<Cell> other) {
    return TestCell<Never>((object, {Cell? host, dynamic arguments, dynamic user}) {
      return other.call(object, host: host, arguments: arguments);
    });
  }

  @override
  FutureOr<bool> action(Function action, {required Cell host, Arguments? arguments}) {
    if (host.modifiable.contains(action)) return false;
    final elements = [
      if (arguments?.positionalArguments != null) ...arguments!.positionalArguments!,
      if (arguments?.namedArguments != null) ...arguments!.namedArguments!.values,
    ];
    _checkArguments(elements, 0, host, action);
    return _checkActionRules(action, host, arguments);
  }

  @override
  FutureOr<bool> call(object, {covariant Cell? host, arguments}) {
    if (object is Function && host != null) {
      return action(object, host: host);
    }
    return true;
  }

  @override
  FutureOr<bool> link(covariant Cell link, {required Cell host}) {
    return true;
  }

  @override
  FutureOr<bool> pulse(covariant Pulse<dynamic> pulse, {required Cell host}) {
    return true;
  }

  @override
  FutureOr<bool> _checkActionRules(Function action, Cell host, Arguments? arguments) {
    return true;
  }

  @override
  FutureOr<bool> _checkArguments(List<dynamic> elements, int index, Cell host, Function action) {
    return true;
  }

}
