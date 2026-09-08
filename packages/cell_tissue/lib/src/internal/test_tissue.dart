// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// Base type for Tissue test rules
typedef TestTissueBase<E, C extends Tissue<E>> = TestTissue<E,C>;

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
/// ### Non‑obvious
/// - Because it is host‑agnostic, it can be assigned to any tissue type
///   without type variance issues.
/// - When used with `+`, the operator wraps the other rule into a new
///   [TestTissue] that delegates to it, ensuring that `allowAll + customRule`
///   behaves exactly like `customRule` alone.
/// - It does not participate in exception handling – since it never throws,
///   it doesn't affect the governed/ungoverned exception rules.
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
class _TestTissueNever implements TestTissue<Never, Never>, TestPasses {

  const _TestTissueNever();

  @override
  TestTissue<Never, Never> operator +(covariant TestRule<Never> other) {
    return TestTissue<Never,Never>.chain(const [],
        strategy: (object, {Never? host, dynamic arguments, dynamic user}) => other.call(object, host: host, arguments: arguments)
    );
  }

  @override
  get _record => ();

  @override
  Iterable<TestRule<Never>> get _rules => const Iterable.empty();

  @override
  FutureOr<bool> action(Function action, {required Cell host, Arguments? arguments}) {
    return true;
  }

  @override
  FutureOr<bool> call(object, {covariant Cell? host, arguments}) {
    return true;
  }

  @override
  FutureOr<bool> element(covariant dynamic element, {required Cell host, Function? action}) {
    return true;
  }

  @override
  FutureOr<bool> link(covariant Cell link, {required Cell host}) {
    return false;
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
///
/// See also:
/// - [TestTissue.readOnly] – the canonical constant.
/// - [TestTissue.allowAll] – the permissive counterpart.
class _TestTissueReadOnly implements TestTissue<Never,Never> {

  const _TestTissueReadOnly();

  @override
  TestTissue<Never,Never> operator +(covariant TestRule<Cell> other) {
    return TestTissue<Never,Never>(
          (object, {Cell? host, dynamic arguments, dynamic user}) {
        return other.call(object, host: host, arguments: arguments);
      },
    );
  }

  @override
  get _record => ();

  @override
  Iterable<TestRule<Never>> get _rules => const Iterable.empty();

  @override
  FutureOr<bool> action(Function action, {required Cell host, Arguments? arguments}) {
    return !host.modifiable.contains(action);
  }

  @override
  FutureOr<bool> call(object, {covariant Cell? host, arguments}) {
    if (object is Function && host != null) {
      return action(object, host: host);
    }
    return true;
  }

  @override
  FutureOr<bool> link(covariant Cell link, {required Never host}) {
    return true;
  }

  @override
  FutureOr<bool> pulse(covariant Pulse<dynamic> pulse, {required Cell host}) {
    return true;
  }

  @override
  FutureOr<bool> element(covariant Never? element, {required Never host, Function? action}) {
    return true;
  }

}