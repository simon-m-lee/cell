// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';

/// Provides a fluent, functional API for operating on individual [Pulse] instances.
///
/// This extension enables payload transformation and metadata management while
/// maintaining the causal integrity of the signal as it propagates through the
/// cell graph.
extension PulseExtension<P> on Pulse<P> {

  /// Transforms the payload of this pulse into a new type [T] while preserving
  /// its causal history.
  ///
  /// This method is the primary way to evolve a signal across different logical
  /// layers of an application (e.g., mapping a raw network `int` status to a
  /// UI-ready `String` message).
  ///
  /// ### How it works
  /// 1.  It applies the [mapper] function to the current [payload].
  /// 2.  It creates a new [Pulse] instance with the result.
  /// 3.  It calls [evolve] to link the new pulse to this instance as its
  ///     parent, ensuring the [trace] and [context] are carried forward.
  ///
  /// ### Example
  /// ```dart
  /// final countPulse = Pulse<int>(10);
  ///
  /// // Transform int payload to String while keeping causal history
  /// final displayPulse = countPulse.map((count) => 'Current count: $count');
  ///
  /// print(displayPulse.payload); // "Current count: 10"
  /// print(displayPulse.trace);   // Shows the path from countPulse
  /// ```
  ///
  /// ### Non‑obvious
  /// [Pulse] is an [Iterable], so `pulse.map(...)` resolves to [Iterable.map].
  /// Call this as `PulseExtension(pulse).map(...)` (as [mapEach] does).
  /// The result is an [EvolvedPulse] whose [EvolvedPulse.parent] is `this`.
  /// Mixed-type mapping (`int` → `String`) cannot walk [Pulse.root]: `root`
  /// casts the ancestor as `PulseBase<P>` of the child type. Use
  /// [EvolvedPulse.parent] instead. Same-type mapping keeps `root`.
  Pulse<T> map<T>(T Function(P payload) mapper) {
    // 1. Transform the payload.
    // We cast 'payload' to P to satisfy non-nullable type expectations if necessary.
    final transformedValue = mapper(payload as P);

    // 2. Create the new pulse instance.
    final newPulse = Pulse<T>(transformedValue);

    // 3. Evolve this pulse with the mapped child so the result is Pulse<T>
    //    (payload type of the child) and this instance remains the parent.
    return evolve(pulse: newPulse) as Pulse<T>;
  }

  /// Returns a new version of this pulse with updated [context] metadata.
  ///
  /// Use this method to inject diagnostic information, security credentials,
  /// or timestamps into a pulse without altering its core [payload].
  ///
  /// ### When to use
  /// * **Tracing**: Attaching a unique request ID to track a signal's lifecycle.
  /// * **Authorization**: Injecting user permissions into a pulse before it
  ///   reaches a protected receptor.
  /// * **Auditing**: Adding a timestamp to mark when a specific processing
  ///   stage was reached.
  ///
  /// ### Example
  /// ```dart
  /// final data = Pulse('Secure Data');
  ///
  /// // Attach metadata fluently
  /// final authenticatedPulse = data.attach({'user': 'admin', 'role': 'editor'});
  ///
  /// print(authenticatedPulse.context); // {'user': 'admin', 'role': 'editor'}
  /// ```
  Pulse<P> attach(dynamic context) {
    return evolve(context: context) as Pulse<P>;
  }

  /// Executes a side-effect [action] using the current [payload] and returns
  /// this pulse instance.
  ///
  /// This operator allows you to "peek" at the data flowing through a pulse
  /// chain without modifying the payload, context, or causal trace. It is
  /// primarily used for non-destructive operations like logging or debugging.
  ///
  /// ### When to use
  /// *   **Logging**: Recording the state of a pulse at a specific point in
  ///     its lifecycle.
  /// *   **Debugging**: Inserting breakpoints or print statements into a
  ///     fluent chain to inspect data.
  /// *   **External Triggers**: Triggering analytics or external notifications
  ///     that do not depend on the reactive graph's result.
  ///
  /// ### How it works
  /// The [action] is executed immediately with the pulse's [payload]. Because
  /// it returns `this`, you can continue chaining other operators like [map]
  /// or [attach] seamlessly.
  ///
  /// ### Example
  /// ```dart
  /// final pulse = Pulse(42)
  ///   .tap((val) => print('Intercepted value: $val'))
  ///   .map((val) => val * 2);
  ///
  /// // Output: Intercepted value: 42
  /// // Result: Pulse(84)
  /// ```
  Pulse<P> tap(void Function(P payload) action) {
    action(payload as P);
    return this;
  }

  /// Re-casts the pulse payload to type [T] while maintaining causal history.
  ///
  /// Use this method to explicitly define the expected payload type when the
  /// compiler has lost track of it (e.g., after an evolution that returns
  /// `Pulse<dynamic>`) or when narrowing a type for specific receptor processing.
  ///
  /// ### When to use
  /// *   **Type Narrowing**: Transitioning from a general type (e.g., `Object` or
  ///     `dynamic`) to a specific domain model after validation.
  /// *   **Recovering Type Safety**: Explicitly setting the type parameter [T]
  ///     after calling internal methods that return generic pulses, ensuring
  ///     downstream receptors receive type-safe data.
  ///
  /// ### How it works
  /// This method performs a runtime cast of the current [payload] to [T]. It then
  /// creates a new [Pulse<T>] instance and calls [evolve] to link it to the
  /// current pulse as its causal parent, preserving the [trace] and [context].
  ///
  /// ### Example
  /// ```dart
  /// final Pulse<dynamic> dynamicPulse = Pulse(100);
  ///
  /// // Safely cast to a specific type to enable type-specific operations
  /// final intPulse = dynamicPulse.cast<int>();
  ///
  /// print(intPulse.payload.isEven); // True
  /// print(intPulse.trace);          // Causal history is preserved
  /// ```
  ///
  /// ### Non‑obvious
  /// [Pulse] is an [Iterable], so `pulse.cast<T>()` resolves to [Iterable.cast].
  /// Call this as `PulseExtension(pulse).cast<T>()`. The result is an
  /// [EvolvedPulse] whose [EvolvedPulse.parent] is `this`. If `P` is not a
  /// subtype of `T`, [Pulse.root] throws (same mixed-type `PulseBase<P>` cast).
  Pulse<T> cast<T>() {
    return evolve(pulse: Pulse<T>(payload as T)) as Pulse<T>;
  }

}

/// Fluent extensions for collections of [Pulse] objects.
///
/// These operators provide high-level aggregation and normalization utilities for
/// handling multiple signals simultaneously within a reactive propagation cycle.
extension PulseIterableExtension on Iterable<Pulse> {

  /// Aggregates multiple signals into a single, flat [CollectivePulse].
  ///
  /// This is the fluent equivalent of calling [Pulse.batch]. It is the preferred
  /// way to bundle signals when you have a dynamic collection of pulses or when
  /// you want a flat structure rather than the nested hierarchy created by the
  /// binary `+` operator.
  ///
  /// ### When to use
  /// * **Atomic Batching**: Sending multiple related updates (e.g., from a list
  ///   of changed items) through the graph in a single propagation step.
  /// * **Flattening**: Ensuring that even if the source list contains
  ///   composite pulses, the result is a single-level collection.
  ///
  /// ### Comparison: `+` vs `.batch()`
  /// | Feature | `p1 + p2 + p3` | `[p1, p2, p3].batch()` |
  /// | :--- | :--- | :--- |
  /// | **Logic** | Binary Composition (Nested) | Flat Aggregation |
  /// | **Structure** | `[[p1, p2], p3]` | `[p1, p2, p3]` |
  /// | **Length** | 2 | 3 |
  ///
  /// ### Example
  /// ```dart
  /// final updates = [Pulse('A'), Pulse('B'), Pulse('C')];
  /// final collective = updates.batch();
  ///
  /// print(collective.length); // 3
  /// ```
  Pulse batch() => Pulse.batch(this);

  /// Recursively flattens any nested [CollectivePulse] structures into a
  /// sequence of simple pulses.
  ///
  /// Use this to normalize pulses created via the `+` operator before
  /// performing terminal operations, logging, or custom iteration. This ensures
  /// that binary-composed signals are treated as a linear stream of events.
  ///
  /// ### How it works
  /// This method performs a depth-first traversal of the pulse tree. If a pulse
  /// [Pulse.isComposite], its payload is recursively flattened; otherwise, the
  /// pulse itself is yielded.
  ///
  /// ### Example
  /// ```dart
  /// final p1 = Pulse(1);
  /// final p2 = Pulse(2);
  /// final p3 = Pulse(3);
  ///
  /// // Binary composition creates nesting: [[p1, p2], p3]
  /// final nested = (p1 + p2) + p3;
  ///
  /// // Flattening restores the linear sequence
  /// final flat = [nested].flatten().toList();
  ///
  /// print(flat.length); // 3
  /// print(flat);        // [Pulse(1), Pulse(2), Pulse(3)]
  /// ```
  Iterable<Pulse> flatten() sync* {
    for (final pulse in this) {
      if (pulse.isComposite) {
        // Yield from the underlying collection if it's a CollectivePulse
        yield* (pulse.payload as Iterable<Pulse>).flatten();
      } else {
        yield pulse;
      }
    }
  }

  /// Appends a diagnostic stage to the causal trace of every pulse in this
  /// collection.
  ///
  /// Use this method to document a shared processing milestone for a group of
  /// signals simultaneously. This is particularly useful when a batch of
  /// pulses passes through a common gateway, validator, or middleware stage.
  ///
  /// ### When to use
  /// *   **Bulk Auditing**: Marking a set of signals as having cleared a specific
  ///     logical hurdle (e.g., `'security-cleared'`, `'schema-validated'`).
  /// *   **Pipeline Tracking**: Tracking a collection of signals as they move
  ///     through complex multi-stage transformations.
  ///
  /// ### How it works
  /// This is a fluent wrapper that applies [Pulse.withStep] to every element in
  /// the iterable. It returns a new sequence of evolved pulses, each
  /// maintaining its own individual causal link to its parent while sharing
  /// the new trace entry.
  ///
  /// ### Example
  /// ```dart
  /// final signals = [Pulse('data1'), Pulse('data2')];
  ///
  /// // Mark the entire batch as sanitized
  /// final sanitized = signals.withStep('sanitized');
  ///
  /// for (final p in sanitized) {
  ///   print(p.trace); // [..., 'sanitized']
  /// }
  /// ```
  Iterable<Pulse> withStep(String step) => map((p) => p.withStep(step));

  /// Returns a new collection of pulses, each with the provided [context]
  /// metadata attached.
  ///
  /// Useful for injecting shared request IDs, timestamps, or session data into
  /// multiple signals at once.
  Iterable<Pulse> attach(dynamic context) => map((p) => p.attach(context));

  /// Transforms the payload of every pulse in the collection while
  /// preserving their individual causal traces.
  ///
  /// This ensures that the "story" of each individual signal is maintained
  /// even during bulk transformations.
  ///
  /// ### Example
  /// ```dart
  /// final pulses = [Pulse(1), Pulse(2)];
  /// final strings = pulses.mapEach((val) => 'Value: $val');
  /// ```
  Iterable<Pulse<T>> mapEach<T>(T Function(dynamic payload) mapper) =>
      // explicitly cast to PulseExtension to avoid conflict with Iterable.map
  map((p) => PulseExtension(p).map<T>((payload) => mapper(payload)));

}