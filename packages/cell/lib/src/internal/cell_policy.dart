// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Defines the **Lifecycle Governance** for transient reactive nodes.
///
/// `EphemeralPolicy` gives a [Cell] — or any cell-backed node such as a
/// `Tissue` collection — a finite operational life. The framework reclaims
/// the node automatically when a time budget ([duration]) elapses or an
/// event budget ([eventLimit]) is exhausted. This prevents memory leaks and
/// guarantees that transient state never outlives its usefulness.
///
/// ### What constitutes a governed cell
///
/// A cell is **governed** when it has an [EphemeralPolicy], either directly
/// or inherited from upstream:
///
/// 1. **Hosted (local) policy** — the policy is stored in the cell's own
///    [Nucleus], or in its `principal` chain (which is how a deputy inherits
///    the policy of the nucleus it extends). This is what
///    `Cell.governed(ephemeralPolicy: ...)`,
///    `Cell.deputy(ephemeralPolicy: ...)`, and the `Tissue*Nucleus` factories
///    establish. The cell ticks *this* policy for its own activity.
/// 2. **Upstream (bind) policy** — when the cell hosts no policy of its own,
///    the framework walks up the upstream [Cell.bind] chain and adopts the
///    first policy it finds there. This is the **"head owns the body"** rule:
///    a node bound to a governed head reports `isGoverned == true` and
///    mirrors the head's `isInvalidated` state.
///
/// A hosted policy always takes precedence over one found upstream, so a
/// body part can deliberately override the policy inherited from the head of
/// its reactive graph.
///
/// ### How the policy works
///
/// You provide two callbacks:
/// - `onEvent`: invoked whenever the governed cell ticks the policy for an
///   interaction (a pulse flowing through the cell, an action, a link, or a
///   data mutation). Return the new `events` count — a usage meter, an error
///   budget, or any other quota you choose.
/// - `onInvalidate`: invoked when the policy reaches its terminal condition.
///   Perform any cleanup and return `true` to confirm the node was reclaimed.
///
/// ### Non-obvious
///
/// - The TTL timer starts lazily on the **first interaction**, not at policy
///   creation.
/// - If both [duration] and [eventLimit] are set, whichever condition fires
///   first triggers invalidation.
/// - A shared policy is ticked **once per pulse** regardless of how many
///   governed cells that pulse visits. Without this per-policy, per-pulse
///   guard, a pulse emitted by the head of a bound chain would be counted
///   again at every governed downstream cell that inherits the same policy.
/// - A body that hosts its own policy is governed exclusively by it: its
///   `isInvalidated` reflects only the body's policy, not the head's.
///
/// ### Example: cache with a 5-minute TTL
///
/// ```dart
/// final cachePolicy = EphemeralPolicy(
///   duration: Duration(minutes: 5),
///   onEvent: (object, {required cell, policy, arguments, user}) {
///     // Reset the counter on a cache hit – extends the TTL window.
///     return (events: 0);
///   },
///   onInvalidate: (nucleus) {
///     // Clear cache entries.
///     return true;
///   },
/// );
///
/// final cell = Cell.governed(
///   ephemeralPolicy: cachePolicy,
///   context: Context.system,
/// );
/// ```
///
/// See also:
/// - [Cell.isGoverned] and [Cell.isInvalidated] for how governance cascades.
/// - [Cell.governed] and [Cell.deputy] for attaching a policy to a cell.
/// - [PulseEphemeralPolicy] — the equivalent lifecycle for individual pulses.
/// {@category Advanced}
/// {@category Ephemeral Policy}
class EphemeralPolicy<C extends Cell> {
  /// Internal flyweight record storing the policy configuration and state.
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  /// A handle to the active timer for Time-To-Live (TTL) enforcement.
  Timer? _ttlTimer;

  /// Synthesizes a new [EphemeralPolicy] to manage the **Lifecycle Reclamation**
  /// of a transient cell.
  ///
  /// ### When to use
  /// Create this policy and attach it to a cell that should not live forever.
  ///
  /// ### Attaching the policy
  /// The policy travels inside the cell's [Nucleus] record:
  /// - `Cell.governed(ephemeralPolicy: policy, context: ...)` — a new governed
  ///   cell that hosts the policy locally.
  /// - `cell.deputy(ephemeralPolicy: policy)` — a governed deputy that hosts
  ///   the policy locally, overriding any policy inherited from its principal
  ///   or upstream bind chain.
  /// - `Tissue.governed(...)`, `TissueListNucleus(...)`, `TissueSetNucleus(...)`,
  ///   and the other `Tissue*Nucleus` factories — the equivalent entry points
  ///   for governed tissue collections.
  ///
  /// A cell that hosts no policy of its own still inherits governance from
  /// upstream: the framework locates the nearest [EphemeralPolicy] on the
  /// [Cell.bind] chain, so a node bound to a governed head behaves as a
  /// governed body.
  ///
  /// ### How it works
  /// - `onEvent` is called on every pulse, action, or link; update the
  ///   `events` count and return the new count. Use this to track usage.
  /// - `onInvalidate` is called when the cell should be destroyed; perform
  ///   cleanup and return `true` to confirm.
  /// - The [duration] and [eventLimit] are optional; you can use one or both.
  ///
  /// ### Non‑obvious
  /// - Returning a negative `events` count from `onEvent` will ignore the event.
  /// - The TTL timer starts only on the first interaction, not at creation.
  /// - A hosted policy wins over an upstream one; a body can therefore
  ///   override the lifecycle policy of the head of its reactive graph.
  ///
  /// ### Parameters:
  /// * `onEvent`: A user-defined logic function called on every pulse to
  ///   calculate the current `events` count (e.g., tracking errors or usage).
  /// * `onInvalidate`: The mandatory execution hook that performs the
  ///   actual removal or neutralization of the cell from the system.
  /// * `eventLimit`: The maximum threshold for the `events` count.
  /// * `duration`: The maximum lifespan of the cell (TTL).
  /// * `user`: Optional metadata for tracking custom parameters or semantic tags.
  EphemeralPolicy(
      {required ({int events}) Function(dynamic object,
              {required C cell,
              dynamic arguments,
              required EphemeralPolicy policy,
              dynamic user})
          onEvent,
      required bool Function(Nucleus nucleus) onInvalidate,
      int? eventLimit,
      Duration? duration,
      dynamic user})
      : _record = mask(
            onEvent: onEvent,
            eventLimit: eventLimit,
            duration: duration,
            onInvalidate: onInvalidate,
            user: user);

  /// The maximum **Time-To-Live (TTL)** for the associated cell.
  ///
  /// Once this `duration` has elapsed from the moment of the first interaction,
  /// the `EphemeralPolicy` will trigger a mandatory invalidation, regardless
  /// of how many pulses have been processed.
  ///
  /// ### Human Developer Usage
  /// Use this to create self-cleaning resources:
  ///
  /// ```dart
  /// // Cell expires after 30 seconds of inactivity
  /// final policy = EphemeralPolicy(
  ///   duration: Duration(seconds: 30),
  ///   // ... callbacks
  /// );
  /// ```
  Duration? get duration =>
      get<Duration?>(() => _record.duration, orElse: null);

  /// The maximum threshold of `events` permitted before the cell is
  /// automatically reclaimed.
  ///
  /// This property defines the **Operational Quota** for the lifecycle of
  /// the node. Once the internal `events` counter—which may track usage,
  /// errors, or custom triggers—meets or exceeds this value, the
  /// [EphemeralPolicy] triggers a mandatory invalidation of the cell.
  ///
  /// ### Human Developer Usage
  /// Use event limits for:
  /// - **Rate Limiting**: Reclaim cells that exceed operation quotas
  /// - **Error Budgets**: Auto-cleanup on excessive errors
  /// - **Usage Tracking**: Limit operations per cell
  ///
  /// ```dart
  /// // Reclaim after 1000 operations
  /// final policy = EphemeralPolicy(
  ///   eventLimit: 1000,
  ///   onEvent: (object, {required cell, policy, arguments, user}) {
  ///     return (events: policy.events + 1);
  ///   },
  ///   // ... onInvalidate
  /// );
  /// ```
  int? get eventLimit => get<int?>(() => _record.eventLimit, orElse: null);

  /// The current count of **Targeted Events** tracked by the lifecycle policy.
  ///
  /// This property represents a specialized counter used to determine the
  /// operational health or lifespan of the cell. Depending on the
  /// [onEvent] logic defined by the user, [events] may represent:
  /// *   **Faulty/Rejected Events**: A "Error Budget" that increments when
  ///     a policy guard or filter rejects a pulse.
  /// *   **Processed Cycles**: A "Usage Quota" that increments with every
  ///     successful signal transformation.
  /// *   **Custom Signal Matches**: A count of specific semantic patterns
  ///     detected within the pulse `payload`.
  ///
  /// ### Human Developer Usage
  /// Monitor this value to track cell health:
  ///
  /// ```dart
  /// final policy = EphemeralPolicy(
  ///   eventLimit: 10,
  ///   onEvent: (object, {required cell, policy, arguments, user}) {
  ///     print('Current events: ${policy.events}');
  ///     return (events: policy.events + 1);
  ///   },
  ///   // ... onInvalidate
  /// );
  /// ```
  int get events => get<int>(() => _record.events.value, orElse: 0);

  /// Returns `true` if the [Cell] has reached its terminal state and has
  /// been reclaimed.
  ///
  /// This flag acts as a **Lifecycle Guard**. Once a cell is invalidated,
  /// it is disconnected from the reactive graph, and any subsequent
  /// [Pulse] stimuli will be ignored to prevent state pollution.
  ///
  /// ### Human Developer Usage
  /// Always check this before interacting with a cell:
  ///
  /// ```dart
  /// if (cell.isInvalidated) {
  ///   // Cell is no longer valid, create a new one
  ///   return;
  /// }
  /// // Use the cell safely
  /// ```
  bool get isInvalidated =>
      get<bool>(() => _record.invalidated.value, orElse: false);

  /// An optional, user-defined metadata object for tracking custom parameters.
  ///
  /// The `_user` property allows developers to attach arbitrary data or
  /// **Strategic Annotations** to the policy. This is particularly useful
  /// for providing additional context to the [onEvent] logic without
  /// hard-coding values into the predicate.
  ///
  /// ### Human Developer Usage
  /// Use this to pass configuration or context to the policy:
  ///
  /// ```dart
  /// final policy = EphemeralPolicy(
  ///   user: {'retry_count': 3, 'timeout': 500},
  ///   onEvent: (object, {required cell, policy, arguments, user}) {
  ///     final retryCount = (user as Map)['retry_count'] as int;
  ///     // Use retryCount in logic
  ///     return (events: 0);
  ///   },
  ///   // ... onInvalidate
  /// );
  /// ```
  dynamic get _user => get<dynamic>(() => _record.user, orElse: null);

  /// Orchestrates the **Lifecycle Reclamation Check** across multiple
  /// interaction vectors.
  ///
  /// This method is invoked by the host [Cell] or its [Receptor] whenever
  /// a node interaction occurs (e.g., within `TestCell` evaluation). It
  /// coordinates the evaluation of the [events] counter and the management
  /// of the [duration] timer.
  ///
  /// ### 1. Operational Vectors ([object])
  /// The [object] varies based on the trigger that initiated the check:
  /// *   **Signal Vector**: A [Pulse] being propagated through the node.
  /// *   **Action Vector**: A [String] identifier of a method being invoked.
  /// *   **Link Vector**: A [Cell] reference attempting to observe this node.
  /// *   **Data Vector**: The new state `value` or `element` being committed.
  ///
  /// ### 2. Execution Pipeline:
  /// *   **Terminal Guard**: Immediately aborts if [isInvalidated] is true,
  ///     ensuring no logic executes on a reclaimed node.
  /// *   **Temporal Initialization**: Lazily starts the **Time-To-Live (TTL)**
  ///     timer upon the very first interaction ([call]) with the cell.
  /// *   **Event Analysis**: Executes the user-defined `onEvent` logic to
  ///     update the stateful [events] counter based on the provided [object]
  ///     and any execution [arguments].
  /// *   **Threshold Enforcement**: Compares the updated counter against
  ///     the [eventLimit]. If reached, it triggers the internal reclamation
  ///     mechanism.
  ///
  /// ### Parameters:
  /// - [object]: The polymorphic interaction payload (Pulse, String action, etc.).
  /// - [cell]: The live [Cell] instance governed by this policy.
  /// - [arguments]: Optional execution arguments or parameters associated
  ///   with the trigger.
  ///
  /// ### Human Developer Usage
  /// This method is called automatically by the framework. Developers
  /// should not call it directly.
  void call(dynamic object, {required C cell, dynamic arguments}) {
    if (isInvalidated) return;

// Initialize TTL timer on the first interaction if configured
    if (duration != null && _ttlTimer == null) {
      _ttlTimer = Timer(duration!, () => _triggerReclamation(cell));
    }

    final onEvent = get<Function>(() => _record.onEvent);
    final handle = onEvent(object,
        cell: cell, policy: this, user: _user, arguments: arguments);

    if (handle.events >= 0) {
      _record.events.value = handle.events;

// Check against Event Limit
      final limit = eventLimit;
      if (limit != null && handle.events >= limit) {
        _triggerReclamation(cell);
        dispose();
      }
    }
  }

  /// Internal mechanism to execute the reclamation logic.
  void _triggerReclamation(C cell) {
    if (isInvalidated) return;

    final onInvalidate = get<Function>(() => _record.onInvalidate);
    final success = onInvalidate(cell._nucleus);

    if (success) {
      _record.invalidated.value = true;
      _ttlTimer?.cancel();
      _ttlTimer = null;
    }
  }

  /// Disposes of active timers to prevent memory leaks.
  ///
  /// This should be called when the host cell is manually disposed or
  /// when the framework neutralizes the node to ensure background TTL
  /// timers are properly cleaned up.
  void dispose() {
    _ttlTimer?.cancel();
    _ttlTimer = null;
  }

  /// Generates a memory-optimized **Flyweight Record** for the policy.
  static Record mask(
      {required Function onEvent,
      required Function onInvalidate,
      int? eventLimit,
      Duration? duration,
      dynamic user}) {
    final mask = ((eventLimit != null ? 1 : 0) |
        (duration != null ? 2 : 0) |
        (user != null ? 4 : 0));

    return switch (mask) {
      0 => (
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          invalidated: FinalBox<bool>(),
          events: Box<int>()
        ),
      1 => (
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          invalidated: FinalBox<bool>(),
          events: Box<int>(),
          eventLimit: eventLimit
        ),
      2 => (
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          invalidated: FinalBox<bool>(),
          events: Box<int>(),
          duration: duration
        ),
      3 => (
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          invalidated: FinalBox<bool>(),
          events: Box<int>(),
          eventLimit: eventLimit,
          duration: duration
        ),
      4 => (
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          invalidated: FinalBox<bool>(),
          events: Box<int>(),
          user: user
        ),
      5 => (
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          invalidated: FinalBox<bool>(),
          events: Box<int>(),
          eventLimit: eventLimit,
          user: user
        ),
      6 => (
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          invalidated: FinalBox<bool>(),
          events: Box<int>(),
          duration: duration,
          user: user
        ),
      7 => (
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          invalidated: FinalBox<bool>(),
          events: Box<int>(),
          eventLimit: eventLimit,
          duration: duration,
          user: user
        ),
      _ => (
          onEvent: onEvent,
          onInvalidate: onInvalidate,
          invalidated: FinalBox<bool>(),
          events: Box<int>()
        )
    };
  }
}
