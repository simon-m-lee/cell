// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A governance policy that defines the **Lifecycle Constraints** and **Termination Logic**
/// for a [Pulse] as it traverses the reactive graph.
///
/// In the reactive framework, [PulseEphemeralPolicy] implements the **Signal Governance**
/// pattern. It prevents "Zombie Signals" and infinite propagation loops by establishing
/// hard boundaries for both temporal duration (TTL) and topological distance (Hops).
///
/// ### Where to start
/// You create a pulse policy when you need a signal to self‑destruct after a
/// certain time or after it has passed through too many nodes. Attach it to a
/// pulse via [Pulse.governed]:
/// ```dart
/// final policy = PulseEphemeralPolicy(
///   duration: Duration(seconds: 5),
///   onEvent: (cell, {required policy}) => (hops: 0),
///   onInvalidate: (pulse) => print('Pulse expired'),
/// );
/// final pulse = Pulse.governed<int>(payload: 42, policy: policy);
/// ```
///
/// ### When to use
/// Use this when you need to:
/// - Ensure a command is only valid for a short window (e.g., one‑time tokens).
/// - Limit how far a signal can propagate to avoid infinite loops.
/// - Automatically clean up stale messages in a distributed system.
/// - Implement time‑based or hop‑based circuit breakers.
///
/// ### How it works
/// - The policy tracks the number of **hops** (node traversals) via `onEvent`.
/// - It starts a **TTL timer** on the first interaction with any cell.
/// - When either the hop limit or the TTL is exceeded, the `onInvalidate`
///   callback is triggered, and the pulse is marked as invalid.
/// - Invalidation is checked automatically by the framework before processing
///   a pulse; invalidated pulses are silently dropped.
/// - The policy is **stateless** except for the hop counter and invalidation flag,
///   which are stored in a lightweight record.
///
/// ### Non‑obvious
/// - The TTL timer starts **lazily** – only when the pulse first interacts
///   with a cell, not at creation time. This avoids unnecessary timers for
///   pulses that are never propagated.
/// - If both `duration` and `hopLimit` are set, the policy invalidates as soon
///   as **either** condition is met.
/// - The `onEvent` callback must return a `({int? hops})` record. Returning
///   `null` for `hops` means no hop increment (useful for resetting counters).
/// - The policy is attached to a **specific pulse instance**; it does not
///   affect the cell's lifecycle policy.
/// - The `onInvalidate` callback receives the invalidated pulse – you can use
///   this for logging, cleanup, or triggering compensatory actions.
///
/// ### Example: Time‑Sensitive Authentication Token
/// ```dart
/// final authPolicy = PulseEphemeralPolicy(
///   duration: Duration(minutes: 5),
///   onEvent: (cell, {required policy}) => (hops: 0),
///   onInvalidate: (pulse) {
///     print('Token expired. Re‑authenticate.');
///     return true;
///   },
/// );
/// final tokenPulse = Pulse.governed<String>(
///   payload: 'session_123',
///   policy: authPolicy,
/// );
/// ```
///
/// ### Example: Hop‑Limited Broadcast
/// ```dart
/// final broadcastPolicy = PulseEphemeralPolicy(
///   hopLimit: 3,
///   onEvent: (cell, {required policy}) => (hops: policy.hops + 1),
///   onInvalidate: (pulse) => print('Broadcast stopped after 3 hops'),
/// );
/// ```
///
/// See also:
/// * [Pulse.governed] – the factory that attaches a policy to a pulse.
/// * [EphemeralPolicy] – the cell‑level lifecycle policy (similar, but for cells).
/// {@category Advanced}
/// {@category Pulse Ephemeral Policy}
class PulseEphemeralPolicy {

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  /// A handle to the active timer for Time-To-Live (TTL) enforcement.
  Timer? _ttlTimer;

  /// Creates a new [PulseEphemeralPolicy] with the specified lifecycle constraints.
  ///
  /// ### When to use
  /// Use this constructor to define a custom policy. You must provide at least
  /// `onEvent` and `onInvalidate`; `duration` and `hopLimit` are optional but
  /// at least one should be set for the policy to be useful.
  ///
  /// ### How it works
  /// - The `onEvent` function is called every time the pulse reaches a new cell.
  ///   It receives the current cell and the policy instance, and must return a
  ///   record with an optional `hops` value. If `hops` is provided, it updates
  ///   the internal hop counter; if `null`, the counter is unchanged.
  /// - If `hopLimit` is set and the hop counter reaches or exceeds it, the
  ///   pulse is invalidated.
  /// - If `duration` is set, a timer is started on the first call to `onEvent`.
  ///   When the timer fires, the pulse is invalidated.
  /// - When invalidated, the `onInvalidate` callback is invoked with the pulse.
  ///   Return `true` to confirm successful invalidation.
  ///
  /// ### Non‑obvious
  /// - The `onEvent` function can be used to **reset** the hop counter by
  ///   returning `(hops: 0)`. This is useful if you want to count only
  ///   certain types of traversals.
  /// - The `user` parameter is not used by the policy itself but is stored
  ///   in the record for custom logic – you can access it via `policy._user`
  ///   if needed, though it's recommended to keep logic in `onEvent`.
  /// - The timer is **not** automatically cancelled when the pulse is invalidated
  ///   by hop limit – it's cancelled in `_triggerInvalidation` to avoid leaks.
  ///
  /// ### Parameters:
  /// - [onEvent]: Called on each hop. Returns the updated hop count.
  /// - [onInvalidate]: Called when the pulse is invalidated. Return `true` to
  ///   confirm success.
  /// - [hopLimit]: Maximum number of node traversals allowed. If null, no hop limit.
  /// - [duration]: Maximum time‑to‑live for the pulse. If null, no TTL.
  /// - [user]: Optional metadata for custom logic.
  ///
  /// ### Example: Custom Tracking with User Data
  /// ```dart
  /// final policy = PulseEphemeralPolicy(
  ///   hopLimit: 3,
  ///   user: {'start_time': DateTime.now()},
  ///   onEvent: (cell, {required policy}) {
  ///     final startTime = (policy._user as Map)['start_time'] as DateTime;
  ///     print('Processing at ${DateTime.now().difference(startTime)}');
  ///     return (hops: policy.hops + 1);
  ///   },
  ///   onInvalidate: (pulse) {
  ///     print('Signal processing complete');
  ///     return true;
  ///   },
  /// );
  /// ```
  PulseEphemeralPolicy({
    required ({int? hops}) Function(Cell cell,{required PulseEphemeralPolicy policy}) onEvent,
    required bool Function(Pulse pulse) onInvalidate,
    int? hopLimit,
    Duration? duration,
    dynamic user,
  }) : _record = mask(
          onEvent: onEvent,
          hopLimit: hopLimit,
          duration: duration,
          onInvalidate: onInvalidate
        );

  /// The maximum **Time‑To‑Live (TTL)** for the pulse.
  ///
  /// ### When to use
  /// Use this to control how long the signal lives. Once the TTL expires,
  /// the pulse is automatically invalidated.
  ///
  /// ### How it works
  /// The timer starts on the first interaction with a cell. If the pulse
  /// is never processed, the timer never starts, avoiding unnecessary overhead.
  ///
  /// ### Non‑obvious
  /// - The timer is reset if you set a new `duration`? No, it's set at
  ///   construction and cannot be changed.
  /// - If both TTL and hop limit are set, the first one to fire triggers
  ///   invalidation.
  ///
  /// ### Returns:
  /// The [Duration] for the TTL, or `null` if no TTL is set.
  Duration? get duration {
    return get<Duration?>(() => _record.duration, orElse: null);
  }

  /// The maximum number of node transitions (hops) permitted.
  ///
  /// ### When to use
  /// Use this to limit propagation depth – e.g., prevent a broadcast from
  /// traversing more than a certain number of nodes.
  ///
  /// ### How it works
  /// Each call to `onEvent` can increment the hop counter (or not). When the
  /// counter reaches or exceeds this limit, the pulse is invalidated.
  ///
  /// ### Non‑obvious
  /// - The hop counter starts at 0 and is updated by `onEvent`.
  /// - You can reset the counter by returning `(hops: 0)` from `onEvent`.
  ///
  /// ### Returns:
  /// The maximum allowed hop count, or `null` if no hop limit.
  int? get hopLimit {
    return get<int?>(() => _record.hopLimit, orElse: null);
  }

  /// The current number of nodes traversed in the causal chain.
  ///
  /// ### When to use
  /// Use this to inspect the pulse's journey – e.g., in logging or debugging.
  ///
  /// ### How it works
  /// This value is updated by `onEvent` and stored in the policy record.
  /// It starts at 0 and is only meaningful if you increment it in `onEvent`.
  ///
  /// ### Non‑obvious
  /// - The value is not automatically incremented; you must explicitly return
  ///   a new count in `onEvent`.
  /// - If you never increment it, it remains 0, and hopLimit is never reached.
  int get hops {
    return get<int>(() => _record.hops.value, orElse: 0);
  }

  /// Returns `true` if the pulse has been invalidated.
  ///
  /// ### When to use
  /// Check this before processing a pulse to avoid work on stale signals.
  /// The framework does this automatically, but you can also check manually.
  ///
  /// ### How it works
  /// The invalidation flag is set to `true` when TTL or hop limit is exceeded,
  /// and `onInvalidate` is called.
  ///
  /// ### Returns:
  /// `true` if the pulse is no longer valid; `false` otherwise.
  bool get isInvalidated {
    return get<bool>(() => _record.invalidated.value, orElse: false);
  }

  void _onPulseComplete(Pulse pulse, {required Cell cell}) {
    if (isInvalidated) return;

// Initialize TTL timer on the first interaction if configured
    if (duration != null && _ttlTimer == null) {
      _ttlTimer = Timer(duration!, () => _triggerInvalidation(pulse));
    }

    final handle = _record.onEvent(cell, policy: this);
    final hops = handle.hops;

    // `hops: 0` resets the counter (or is a no-op for TTL-only policies).
    // Invalidation is driven only by hopLimit / TTL, not by a zero count.
    if (hops != null && hopLimit != null) {
      _record.hops.value = hops;
      if (hops >= hopLimit!) {
        _triggerInvalidation(pulse);
      }
    }
  }

  void _triggerInvalidation(Pulse pulse) {
    if (isInvalidated) return;

    final onInvalidate = get<Function>(() => _record.onInvalidate);
    final success = onInvalidate(pulse);

    if (success) {
      _record.invalidated.value = true;
    }
  }

  static Record mask(
      {required Function onEvent,
      required Function onInvalidate,
      int? hopLimit,
      Duration? duration,
      dynamic user}) {
    final mask = ((hopLimit != null ? 1 : 0) | (duration != null ? 2 : 0));

    return switch (mask) {
      0 => (onEvent: onEvent, onInvalidate: onInvalidate, invalidated: FinalBox<bool>()),
      1 => (onEvent: onEvent, onInvalidate: onInvalidate, invalidated: FinalBox<bool>(), hopLimit: hopLimit, hops: Box<int>()),
      2 => (onEvent: onEvent, onInvalidate: onInvalidate, invalidated: FinalBox<bool>(), duration: duration),
      3 => (onEvent: onEvent, onInvalidate: onInvalidate, invalidated: FinalBox<bool>(), hopLimit: hopLimit, hops: Box<int>(), duration: duration),
      _ => (onEvent: onEvent, onInvalidate: onInvalidate, invalidated: FinalBox<bool>())
    };
  }
}
