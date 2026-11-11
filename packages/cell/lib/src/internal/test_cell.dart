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
  FutureOr<bool> action(Function action,
      {required Cell host, Arguments? arguments, ApplyCommand? command}) {
    final elements = [
      if (arguments?.positionalArguments != null)
        ...arguments!.positionalArguments!,
      if (arguments?.namedArguments != null)
        ...arguments!.namedArguments!.values,
    ];
    final argResult = _checkArguments(elements, 0, host, action);
    FutureOr<bool> finish() =>
        _checkActionRules(action, host, arguments, command);
    if (argResult is Future<bool>) {
      return argResult.then((passed) => passed ? finish() : false);
    }
    return argResult ? finish() : false;
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
  FutureOr<bool> _checkActionRules(
      Function action, Cell host, Arguments? arguments, ApplyCommand? command) {
    return true;
  }

  @override
  FutureOr<bool> _checkArguments(
      List<dynamic> elements, int index, Cell host, Function action) {
    return true;
  }
}

class _TestCellReadOnly<C extends Cell> extends TestCell<C> {
  const _TestCellReadOnly() : super.fromRecord(());

  @override
  TestCell<C> operator +(covariant TestRule<Cell> other) {
    return TestCell<C>((object, {Cell? host, dynamic arguments, dynamic user}) {
      return other.call(object, host: host, arguments: arguments);
    });
  }

  @override
  FutureOr<bool> action(Function action,
      {required C host, Arguments? arguments, ApplyCommand? command}) {
    // Read-only blocks EVERY function action. Gating by whitelist
    // membership (`host.modifiable.contains(action)`) is dead in practice:
    // a caller-supplied function is never in the freshly allocated
    // tear-off set, so that check only ever saw the framework's own
    // `apply` forwarding tear-off. The read-only contract is simpler:
    // functions are mutations, pulses (non-Function objects) are not.
    return false;
  }

  @override
  FutureOr<bool> call(object, {covariant C? host, arguments}) {
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
  FutureOr<bool> _checkActionRules(
      Function action, Cell host, Arguments? arguments, ApplyCommand? command) {
    return true;
  }

  @override
  FutureOr<bool> _checkArguments(
      List<dynamic> elements, int index, Cell host, Function action) {
    return true;
  }
}
