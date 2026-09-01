// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell.dart';

/// The mixin implementing proxy behavior for [Cell.deputy] — you don't
/// use this directly.
///
/// This exists purely so that a deputy (a proxy sharing its principal's
/// state under a different [TestCell]/[Context]) is architecturally
/// transparent: it's equal to its principal (`==` compares by underlying
/// identity, not object reference), shares its [Lock], and delegates
/// [unmodifiable] correctly. All of that machinery lives here so
/// individual `Cell.*` implementations don't have to reimplement it.
///
/// ### When to use
/// You don't. Use [Cell.deputy] – that's the entire interface you need.
/// It returns a plain [Cell] (or [OpenCell], if called on one); nothing
/// about `Deputy` itself is part of your day-to-day usage.
///
/// ### The one behavior worth knowing
/// A deputy's [TestCell] is always **additive** to its principal's – see
/// [Cell.deputy]'s own docs for what that means in practice. That
/// guarantee is enforced by this mixin, not by convention, so it holds
/// no matter how many layers of `deputy()` you stack.
///
/// See also: [Cell.deputy] (the real entry point), [Cell.unmodifiable]
/// (a specific, common deputy — read-only).
mixin Deputy<C extends Cell> on Cell {

  /// Synthesizes a specialized **Mandate Handle** (Deputy) of this cell, providing
  /// a functionally distinct and scoped interface to the underlying state.
  ///
  /// This method is the primary mechanism for **Mandate Delegation**. It produces
  /// a new [Cell] instance that shares the physical identity and state lock of
  /// the **Principal** but operates under a distinct behavioral and security profile
  /// defined by the provided **Governance** parameters.
  ///
  /// ### When to use
  /// Use this when you need a restricted view of a cell – e.g., read‑only,
  /// scoped authority, temporary access, or sandboxed simulation.
  ///
  /// ### How it works
  /// - You provide a new [context] (authority, clearance, lease) and/or
  ///   an additional [testRule] (validation gate). The deputy shares the
  ///   principal's state and lock but applies the new rules.
  /// - If all parameters are left at their defaults, the method returns
  ///   `this` – no proxy is created.
  ///
  /// ### Non‑obvious
  /// - The deputy's [testRule] is layered *on top* of the principal's rule.
  ///   You can only narrow permissions, never expand them.
  /// - Deputies are logically equal to their principal: `deputy == principal`
  ///   is `true`, so they work seamlessly in [Set]s and [Map]s.
  /// - The deputy gets its own independent [Synapses] registry by default,
  ///   so it can have its own observers separate from the principal.
  ///
  /// ### Common patterns
  /// - **Read‑Only View**: `testRule: TestCell.readOnly`
  /// - **Temporal Lease**: `context` with `lease: Duration(...)`
  /// - **Restricted Clearance**: `context` with `clearance: Clearance.observational`
  /// - **Sandboxed Execution**: `context: DeputyContext.sandbox(...)`
  ///
  /// ### Example: read‑only deputy
  /// ```dart
  /// final readOnly = await cell.deputy(testRule: TestCell.readOnly);
  /// readOnly.value;        // works
  /// readOnly.apply(...);   // blocked – modifiable whitelist is empty
  /// ```
  ///
  /// ### Example: temporary deputy with lease
  /// ```dart
  /// final temporary = await cell.deputy(
  ///   context: DeputyContext.delegate(
  ///     baseContext: Context.system,
  ///     task: 'temp_task',
  ///     clearance: Clearance.operational,
  ///     lease: Duration(minutes: 5),
  ///   ),
  ///   ephemeralPolicy: EphemeralPolicy(
  ///     duration: Duration(minutes: 5),
  ///     onInvalidate: (nucleus) => true,
  ///   ),
  /// );
  /// ```
  ///
  /// ### Parameters:
  /// * [ephemeralPolicy]: **Lifecycle Governance.** Defines the **Temporal Lease**
  ///   and auto-neutralization logic for this mandate. This ensures that the
  ///   deputy’s administrative autonomy is revoked once defined lifecycle
  ///   criteria are met, maintaining **Systemic Homeostasis**.
  /// * [context]: **Capability Manifest.** An optional [DeputyContext] defining the
  ///   operational boundaries and authorization weights. It acts as the primary
  ///   **Ontological Blueprint** used during the **Reciprocal Handshake**.
  /// * [testRule]: **Integrity Gate.** The [TestCell] (System Law) that
  ///   acts as a **Policy Enforcement Point (PEP)**. This facilitates
  ///   **Capability Attenuation**, allowing a high-integrity principal to
  ///   export a restricted projection.
  /// * [synapses]: **Egress Topology.** The **Signal Distribution Network** for
  ///   the deputy. It determines whether this proxy maintains an independent
  ///   **Signal Dispatcher** or utilises the principal's existing egress
  ///   topology. Defaults to an independent registry.
  ///
  /// ### Returns:
  /// A [FutureOr] containing a new [Cell] instance (of type [C]) acting as a
  /// governed, scoped proxy of the principal.
  @override
  FutureOr<C> deputy({
    EphemeralPolicy? ephemeralPolicy,
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestCell.allowAll,
    Synapses synapses = Synapses.enabled,
  });

  /// Resolves the unmodifiable (read-only) view of the underlying cell.
  ///
  /// ### When to use
  /// Use this to get a read‑only version of the cell – e.g., for UI display
  /// or sharing with untrusted components.
  ///
  /// ### How it works
  /// This delegates to the principal's `unmodifiable` getter. If the current
  /// cell is already a deputy, it forwards to the principal's unmodifiable view.
  ///
  /// ### Example
  /// ```dart
  /// final cell = ValueCell<int>(value: 42);
  /// final readOnly = cell.unmodifiable;
  /// print(readOnly.value); // 42
  /// // readOnly.emit(100); // Not available on read-only view
  /// ```
  @override
  C get unmodifiable => (_nucleus.bind as C).unmodifiable as C;

  /// Determines equality based on the underlying source of truth.
  ///
  /// A [Deputy] is considered equal to another [Deputy] or a [Cell] if they
  /// both share the same `bind` identity.
  ///
  /// ### When to use
  /// This is automatic – you don't need to call it. It ensures that deputies
  /// and principals are interchangeable in collections and comparisons.
  ///
  /// ### How it works
  /// Two deputies are equal if they point to the same underlying cell. A deputy
  /// is equal to its principal. This is enforced by comparing the `bind` identity.
  ///
  /// ### Example
  /// ```dart
  /// final cell = ValueCell<int>(value: 42);
  /// final deputy = await cell.deputy();
  /// print(cell == deputy); // true
  /// final set = {cell, deputy}; // Only one entry (identity-based)
  /// ```
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Cell) return false;
    return _nucleus == other._nucleus;
  }

  /// Returns the hash code of the underlying bound cell to maintain
  /// consistency with the overridden [==] operator.
  ///
  /// ### When to use
  /// Automatic – you don't need to call it. It ensures consistent behaviour
  /// in hash‑based collections.
  ///
  /// ### How it works
  /// Walks to the root principal nucleus, matching [Cell] identity so a
  /// deputy and its principal have the same hash.
  @override
  int get hashCode {
    Nucleus? p = _nucleus;
    while (p?.principal != null) {
      p = p!.principal;
    }
    return identityHashCode(p);
  }

}