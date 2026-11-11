// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// Base type for Tissue test rules
typedef TestTissueBase<E, C extends Tissue<E>> = TestTissue<E, C>;

/// A sentinel implementation of [TestTissue] that always authorises every operation.
///
/// This is the framework's default "allow‑all" policy for collections, used when
/// you don't specify a custom rule. It provides zero‑overhead validation –
/// every call returns `true` instantly, with no metadata inspection or context
/// checks.
///
/// ### When to use
/// Use [_TestTissueNever] (exposed as [TestTissue.allowAll]) when you have no
/// security or integrity constraints. It's the fastest possible policy because
/// it short‑circuits all validation with a constant `true`.
///
/// This is the default for collections when no custom rule is provided. It's
/// safe to use for non‑critical data or when you don't need validation.
///
/// ### How it works
/// - It implements all validation hooks (`call`, `action`, `link`, `pulse`,
///   `element`) to unconditionally return `true`.
/// - It is a `const` singleton – every collection that uses `allowAll` points
///   to the exact same instance, saving memory.
/// - When composed with other rules via `+`, it acts as a **compositional
///   identity** – the other rule's logic is preserved, and this rule is
///   effectively a no‑op in the chain.
///
/// ### Example
/// ```dart
/// // Default policy – no restrictions
/// final list = TissueList<int>();
/// print(list.validate is TestTissue.allowAll); // true
///
/// // Composition – allowAll has no effect
/// final policy = TestTissue.allowAll + TestTissue<int>((v) => v > 0);
/// // Equivalent to just the positive rule.
/// ```
///
/// See also:
/// - [TestTissue.allowAll] – the canonical constant.
/// - [TestTissue.readOnly] – the opposite, blocking all mutations.
class _TestTissueNever extends TestTissue<Never, Never> implements TestPasses {
  const _TestTissueNever() : super.fromRecord(());

  @override
  TestTissue<Never, Never> operator +(covariant TestRule<Never> other) {
    // Composing the permissive singleton with itself is a no-op, and
    // `allowAll` is the identity element of the `+` chain.
    if (identical(other, TestTissue.allowAll)) return this;
    // Already-composed allowAll chains stay flattened and host-widened.
    if (other is _TestTissueAllowAll) return other;
    return _TestTissueAllowAll._([other]);
  }

  @override
  FutureOr<bool> action(Function action,
      {required Cell host, Arguments? arguments, ApplyCommand? command}) {
    return true;
  }

  @override
  FutureOr<bool> call(object, {covariant Cell? host, arguments}) {
    return true;
  }

  @override
  FutureOr<bool> element(covariant dynamic element,
      {required Cell host, Function? action}) {
    return true;
  }

  @override
  FutureOr<bool> link(covariant Cell link, {required Cell host}) {
    // The docstring promises every hook unconditionally returns true.
    return true;
  }

  @override
  FutureOr<bool> pulse(covariant Pulse<dynamic> pulse, {required Cell host}) {
    return true;
  }
}

/// Composed form of [TestTissue.allowAll] produced by the `+` operator.
///
/// A plain `TestTissue<Never, Never>.chain` would inherit the `Never`-typed
/// `host` gate from [TestCell.action], which rejects every real [Tissue] at
/// runtime and silently disables mutations through deputies whose rules are
/// layered on top of `allowAll`. This wrapper instead keeps a flattened list
/// of the appended sentinel rules and evaluates them with widened `host`
/// signatures, so deputies remain mutable when their rules permit it.
class _TestTissueAllowAll extends TestTissue<Never, Never>
    implements TestPasses {
  const _TestTissueAllowAll._(this._others) : super.fromRecord(());

  /// The rules appended after [TestTissue.allowAll], in evaluation order.
  final List<TestRule<Never>> _others;

  @override
  TestTissue<Never, Never> operator +(covariant TestRule<Never> other) {
    if (identical(other, TestTissue.allowAll)) return this;
    if (other is _TestTissueAllowAll) {
      return _TestTissueAllowAll._([..._others, ...other._others]);
    }
    return _TestTissueAllowAll._([..._others, other]);
  }

  @override
  FutureOr<bool> action(Function action,
      {required Cell host, Arguments? arguments, ApplyCommand? command}) {
    return _run(action, host: host, arguments: arguments);
  }

  @override
  FutureOr<bool> call(object, {covariant Cell? host, arguments}) {
    return _run(object, host: host, arguments: arguments);
  }

  FutureOr<bool> _run(dynamic object, {Cell? host, dynamic arguments}) {
    FutureOr<bool> runRules(int index) {
      for (var i = index; i < _others.length; i++) {
        // The composed list is heterogeneous in practice: route through
        // the raw rule interface (host is erased to dynamic).
        final result = (_others[i] as TestRule)
            .call(object, host: host, arguments: arguments);
        if (result is Future<bool>) {
          return result.then((passed) {
            if (!passed) return false;
            return runRules(i + 1);
          });
        }
        if (!result) return false;
      }
      return true;
    }

    return runRules(0);
  }

  @override
  FutureOr<bool> element(covariant dynamic element,
      {required Cell host, Function? action}) {
    return true;
  }

  @override
  FutureOr<bool> link(covariant Cell link, {required Cell host}) {
    // The docstring promises every hook unconditionally returns true.
    return true;
  }

  @override
  FutureOr<bool> pulse(covariant Pulse<dynamic> pulse, {required Cell host}) {
    return true;
  }
}

/// A sentinel implementation of [TestTissue] that enforces a strict
/// **Read‑Only Mutation Barrier** for reactive collections.
///
/// This is the framework's restrictive policy used to implement the
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
/// This is a core architectural constant exposed as [TestTissue.readOnly].
///
/// ### How it works
/// - It intercepts all mutation methods (e.g., `add`, `remove`, `clear`).
/// - If the requested function is in the host's `modifiable` whitelist,
///   the rule returns `true` (disallow), effectively blocking the mutation.
/// - It does **not** block observation, iteration, or pulse propagation.
///   A read‑only deputy remains a "Live" node that reflects the source state
///   in real time; it simply lacks "Write‑Back" rights.
///
/// ### Example
/// ```dart
/// final source = TissueList<String>(['A', 'B']);
/// final readOnly = source.deputy(testRule: TestTissue.readOnly);
/// print(readOnly[0]); // 'A' – works
/// readOnly.add('C'); // blocked – throws UnsupportedError
/// source.add('C');   // allowed – readOnly reflects the change
/// ```
///
/// See also:
/// - [TestTissue.readOnly] – the canonical constant.
/// - [TestTissue.allowAll] – the permissive counterpart.
class _TestTissueReadOnly extends TestTissue<Never, Never> {
  const _TestTissueReadOnly() : super.fromRecord(());

  @override
  TestTissue<Never, Never> operator +(covariant TestRule<Cell> other) {
    return TestTissue<Never, Never>(
      (object, {Cell? host, dynamic arguments, dynamic user}) {
        return other.call(object, host: host, arguments: arguments);
      },
    );
  }

  @override
  FutureOr<bool> action(Function action,
      {required Cell host, Arguments? arguments, ApplyCommand? command}) {
    return !host.modifiable.contains(action);
  }

  @override
  FutureOr<bool> call(object, {covariant Cell? host, arguments}) {
    if (object is Function && host != null) {
      return action(object, host: host);
    }
    return true;
  }
}
