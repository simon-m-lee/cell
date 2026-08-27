// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../../cell.dart';

// ─────────────────────────────────────────────────────────────
// Hub routing modes
// ─────────────────────────────────────────────────────────────

/// Defines how a [Cell.hub] decides which spoke (child cell) should receive
/// an incoming signal.
///
/// The [HubRouting] strategy acts like a traffic controller, reading the
/// "address" (the [Pulse.type]) on a signal to determine its destination.
///
/// ### When to use
/// * Think of a [Cell.hub] as a post office and [HubRouting] as the sorting
///   logic. Depending on the mode, the hub can look for an exact name,
///   a zip code (prefix), or broadcast to everyone.
/// * **exact**: When you have one-to-one mapping (e.g., 'command.save' goes
///   only to the 'save' spoke).
/// * **prefix**: When you have hierarchical categories (e.g., all signals
///   starting with 'auth.' go to the Auth module).
/// * **pattern**: When you need flexible wildcard matching (e.g., 'user.*.success').
/// * **multicast**: When multiple parts of your app need to react to the
///   same signal simultaneously.
///
/// ### How it works
/// When a pulse is `HubHandle.emit`ted to the hub, the hub looks at the `Pulse.type`.
/// It then loops through its registered spokes and applies the chosen
/// routing strategy to find a match.
///
/// ### Non‑obvious
/// - **Priority**: If multiple spokes match in a non-multicast mode, the one
///   with the highest priority wins.
/// - **Longest-Prefix**: In `prefix` mode, the hub automatically selects
///   the most specific match (e.g., 'user.login.success' will prefer a spoke
///   named 'user.login' over a spoke named 'user').
///
/// ### Example
/// ```dart
/// // Setting up a prefix-based router
/// final router = Cell.hub(
///   routing: HubRouting.prefix,
///   spokes: {
///     'auth': authHandler,
///     'auth.login': loginHandler, // This will be preferred for 'auth.login'
///   },
/// );
/// ```
enum HubRouting {
  /// Matches the [Pulse.type] exactly against the spoke key.
  ///
  /// **Example**: A pulse with type 'save' only goes to a spoke named 'save'.
  exact,

  /// Matches the beginning of the [Pulse.type].
  ///
  /// This is useful for hierarchical routing. If a pulse type is
  /// 'user.profile.update', it will match a spoke named 'user.profile'
  /// or just 'user'.
  prefix,

  /// Uses wildcard patterns (`*` and `?`) to match the [Pulse.type].
  ///
  /// - `*` matches any sequence of characters.
  /// - `?` matches any single character.
  ///
  /// **Example**: 'logs.*' matches 'logs.info' and 'logs.error'.
  pattern,

  /// Sends the pulse to **every** spoke that matches the key.
  ///
  /// Unlike the other modes which usually pick the "best" match,
  /// multicast treats the signal as a broadcast to all interested parties.
  multicast,
}

/// A configuration record for an individual **Spoke (Destination)**
/// within a [Cell.hub].
///
/// A `SpokeRegistration` acts like a registered address in a post office.
/// It defines the "Who" (`key`), the "How important" (`priority`), and
/// the "What to do" (`handler` or `receptor`) when a signal arrives.
///
/// ### When to use
/// * Use this when building complex hubs that require fine-grained control
///   over routing, such as when multiple handlers might match the same
///   signal or when you need specialized security per spoke.
/// * **Priority Routing**: When two spokes match (e.g., `'user.*'` and
///   `'user.login'`), use `priority` to ensure the specific one wins.
/// * **Custom Filtering**: When the standard [HubRouting] isn't enough,
///   supply a `match` function for complex logic.
/// * **Governed Security**: Use `context` to assign a [DeputyContext]
///   to a specific spoke, enforcing **Capability-Based Access Control**.
/// * **Mixed Routing**: When you need some spokes to use exact matching
///   and others to use pattern matching within the same hub.
/// * **Fallback Routes**: The `key` of a registration can be used as a
///   [Cell.hub] fallback when no other spokes match.
///
/// ### How it works
/// When a hub receives a pulse, it iterates through its list of
/// `SpokeRegistrations`. It compares the `Pulse.type` against the `key`
/// (or runs the `match` predicate). If a match is found, the signal
/// is routed to that spoke's internal cell.
///
/// ### Non‑obvious: the key becomes the spoke's role
/// The `key` also becomes the `role` in the automatically generated
/// [DeputyContext] if one isn't provided. This means the spoke's
/// identity is derived from its routing address.
///
/// ### Non‑obvious: exactly one of handler or receptor must be provided
/// A spoke can be defined either as a simple function (`handler`) or as
/// a full reactive node (`receptor`). They are mutually exclusive — you
/// must provide exactly one. The `handler` is wrapped into a [Receptor]
/// internally if provided alone.
///
/// ### Non‑obvious: priority determines evaluation order
/// Higher `priority` values are evaluated first. When multiple spokes
/// match a signal and the hub is not in multicast mode, the one with the
/// highest priority receives the pulse. This is how you ensure specific
/// routes are preferred over general ones.
///
/// ### Example: Basic Spoke Registration
/// ```dart
/// final registration = (
///   key: 'auth.success',
///   priority: 10,
///   handler: (cell, pulse, {user}) {
///     print('Login successful!');
///     return pulse;
///   },
/// );
/// ```
///
/// ### Example: Governed Spoke with Custom Context
/// ```dart
/// final secureSpoke = (
///   key: 'admin.audit',
///   priority: 20,
///   match: (type) => type?.startsWith('admin.') ?? false,
///   receptor: Receptor((cell, pulse, {user}) {
///     // Process admin audit signals
///     return pulse;
///   }),
///   context: DeputyContext(
///     baseContext: Context.system,
///     authority: 'AUDIT',
///     role: 'Auditor',
///     clearance: Clearance.administrative,
///   ),
/// );
/// ```
///
/// ### Example: Pattern Matching Spoke
/// ```dart
/// final patternSpoke = (
///   key: 'user.*.profile',  // Matches 'user.123.profile', 'user.456.profile'
///   priority: 5,
///   match: (type) => type != null && RegExp(r'^user\..+\.profile$').hasMatch(type),
///   handler: (cell, pulse, {user}) {
///     // Handle user profile updates
///     return pulse;
///   },
/// );
/// ```
///
/// See also:
/// - [Cell.hub] – the factory that uses these registrations.
/// - [HubRouting] – the routing strategies available for hubs.
/// - [HubHandle] – the handle returned by [Cell.hub].
/// - [DeputyContext] – the security context for governed spokes.
typedef SpokeRegistration = ({
  /// The routing address or label used to identify this destination.
  ///
  /// Depending on the [HubRouting] mode, this key is matched against
  /// the incoming [Pulse.type].
  String key,

  /// The precedence of this spoke relative to others.
  ///
  /// When multiple spokes match a single [Pulse.type], the hub uses this
  /// value to decide which one to prefer (unless in `multicast` mode).
  /// Higher values are evaluated and triggered first.
  int priority,

  /// A specialized filter that determines if a signal belongs to this spoke.
  ///
  /// When provided, this logic overrides the global [HubRouting] strategy
  /// for this specific registration. Return `true` to accept the pulse.
  bool Function(String? type)? match,

  /// The functional logic to execute when a pulse is routed to this spoke.
  ///
  /// Use this for "Simple Mode" where you just want to run a function.
  /// Exactly one of [handler] or [receptor] must be non-null.
  Pulse? Function(Cell cell, Pulse pulse, {dynamic user})? handler,

  /// A pre-built reactive object that manages its own state and logic.
  ///
  /// Use this for "Governed Mode" where the spoke is a complex cell with
  /// its own security and lifecycle rules.
  Receptor? receptor,

  /// The specialized permission and identity record for this spoke.
  ///
  /// If provided, this [DeputyContext] enforces specific **Authority**
  /// and **Role** restrictions for all signals arriving at this destination.
  DeputyContext? context,
});

// ─────────────────────────────────────────────────────────────
// implemented _hub
// ─────────────────────────────────────────────────────────────

HubHandle _hub({
  // ── spokes or governedSpokes ──────────────────
  Map<String, Pulse? Function(Cell cell, Pulse pulse, {dynamic user})>? spokes,
  Map<DeputyContext, Receptor>? governedSpokes,

  // ── Advanced API ───────────────────────────────────────
  /// Explicit ordered / prioritised registrations.
  /// When non-null, [spokes] and [governedSpokes] are ignored.
  List<SpokeRegistration>? registrations,

  /// Spoke key (or registration key) used when nothing else matches.
  String? fallback,

  /// Matching strategy applied to every spoke that does not supply its
  /// own [SpokeRegistration.match].
  HubRouting routing = HubRouting.exact,

  /// When true, every matching spoke receives the pulse (in priority
  /// order). When false, only the highest-priority match receives it.
  /// Forced to true when [routing] == [HubRouting.multicast].
  bool multicast = false,

  EphemeralPolicy? ephemeralPolicy,
  Context context = Context.system,
  Cell? bind,
  TestCell testRule = TestCell.allowAll,

  Synapses Function(String role)? distribution,
  void Function(Pulse pulse)? relay,
  bool forceLock = false,
}) {
  // ── 1. Normalise to a single ordered list of registrations ─
  final List<SpokeRegistration> regs = registrations ??
      _registrations(spokes: spokes, governedSpokes: governedSpokes);

  if (regs.isEmpty && fallback == null) {
    throw ArgumentError(
      'Cell.hub requires at least one spoke or a fallback.',
    );
  }

  // Sort by priority descending so higher priority is tried first.
  final ordered = List<SpokeRegistration>.from(regs)
    ..sort((a, b) => b.priority.compareTo(a.priority));

  final effectiveMulticast =
      multicast || routing == HubRouting.multicast;

  // ── 2. Materialise spoke cells ─────────────────────────────
  final Map<String, Cell> spokeCells = {};
  for (final reg in ordered) {
    final role = reg.key;
    final spokeCell = Cell.governed(
      ephemeralPolicy: ephemeralPolicy,
      context: reg.context ?? Context.module(role),
      receptor: reg.receptor ?? Receptor(reg.handler!),
      synapses: distribution != null ? distribution(role) : Synapses.enabled,
    );
    spokeCells[role] = spokeCell;
  }

  // Optional fallback cell (created only when requested).
  Cell? fallbackCell;
  if (fallback != null) {
    // Re-use an existing spoke with that key, or create a silent sink.
    fallbackCell = spokeCells[fallback] ??
        Cell.governed(
          ephemeralPolicy: ephemeralPolicy,
          context: Context.module(fallback),
          receptor: Receptor.passThrough,
          synapses: Synapses.enabled,
        );
    spokeCells.putIfAbsent(fallback, () => fallbackCell!);
  }

  // ── 3. Matcher helpers ─────────────────────────────────────
  bool matches(SpokeRegistration reg, String? type) {
    if (reg.match != null) return reg.match!(type);
    if (type == null) return false;

    switch (routing) {
      case HubRouting.exact:
        return reg.key == type;
      case HubRouting.prefix:
        return type.startsWith(reg.key);
      case HubRouting.pattern:
        return _globMatch(reg.key, type);
      case HubRouting.multicast:
      // Multicast still uses exact match per spoke unless a custom
      // matcher is supplied; the “deliver to all” behaviour is
      // controlled by [effectiveMulticast].
        return reg.key == type;
    }
  }

  // Longest-prefix helper (only meaningful for prefix routing).
  SpokeRegistration? longestPrefixMatch(String? type) {
    if (type == null) return null;
    SpokeRegistration? best;
    for (final reg in ordered) {
      if (reg.match != null) {
        if (reg.match!(type)) return reg; // custom matcher wins immediately
        continue;
      }
      if (type.startsWith(reg.key)) {
        if (best == null || reg.key.length > best.key.length) {
          best = reg;
        }
      }
    }
    return best;
  }

  // ── 4. Default relay ───────────────────────────────────────
  void defaultRelay(Pulse pulse) {
    final type = pulse.type;
    final List<Cell> targets = [];

    if (effectiveMulticast) {
      // Deliver to every matching spoke (already priority-ordered).
      for (final reg in ordered) {
        if (matches(reg, type)) {
          targets.add(spokeCells[reg.key]!);
        }
      }
    } else if (routing == HubRouting.prefix) {
      final best = longestPrefixMatch(type);
      if (best != null) targets.add(spokeCells[best.key]!);
    } else {
      // exact / pattern – first (highest priority) match wins
      for (final reg in ordered) {
        if (matches(reg, type)) {
          targets.add(spokeCells[reg.key]!);
          break;
        }
      }
    }

    // Fallback when nothing matched.
    if (targets.isEmpty && fallbackCell != null) {
      targets.add(fallbackCell);
    }

    for (final spoke in targets) {
      spoke._nucleus.receptor.call(pulse);
    }
  }

  // ── 5. Root cell & handle ────────────────
  final receptor = Receptor((cell, input, {user}) => input);
  final cell = Cell.governed(
    ephemeralPolicy: ephemeralPolicy,
    context: context,
    receptor: receptor,
    testRule: testRule,
    synapses: Synapses(
      downstreams: spokeCells.values,
      relay: relay ?? defaultRelay,
    ),
    bind: bind,
    forceLock: forceLock,
  );

  Pulse? emit(Pulse pulse) {
    final result = receptor.call(pulse);
    return result is! Future ? result : null;
  }

  Future<Pulse?> emitAsync(Pulse pulse) {
    final lock = cell._nucleus.lock;
    if (lock != null) {
      return lock.synchronized(() => emit(pulse));
    }
    return Future<Pulse?>(() => emit(pulse));
  }

  Future<void> ingest(Pulse pulse, {bool serializedCompletion = true}) {
    return receptor.async.call(
      pulse as PulseBase,
      serializedCompletion: serializedCompletion,
    );
  }

  return (
    root: cell,
    spokes: spokeCells.values,
    emit: emit,
    emitAsync: emitAsync,
    ingest: ingest,
  );
}

// ─────────────────────────────────────────────────────────────
// spokes or governedSpokes registration
// ─────────────────────────────────────────────────────────────

List<SpokeRegistration> _registrations({
  Map<String, Pulse? Function(Cell cell, Pulse pulse, {dynamic user})>? spokes,
  Map<DeputyContext, Receptor>? governedSpokes,
}) {
  assert(
  (spokes == null) != (governedSpokes == null) ||
      (spokes == null && governedSpokes == null),
  'Cell.hub requires exactly one of `spokes` or `governedSpokes` '
      '(or use the new `registrations` list).',
  );

  if (spokes != null) {
    return spokes.entries
        .map((e) => (
    key: e.key,
    priority: 0,
    match: null,
    handler: e.value,
    receptor: null,
    context: null,
    ))
        .toList();
  }

  if (governedSpokes != null) {
    return governedSpokes.entries
        .map((e) {
      final role = e.key.role ?? e.key.hashCode.toString();
      return (
      key: role,
      priority: 0,
      match: null,
      handler: null,
      receptor: e.value,
      context: e.key,
      );
    })
        .toList();
  }

  return const [];
}

// ─────────────────────────────────────────────────────────────
// Simple glob matcher (`*` and `?`)
// ─────────────────────────────────────────────────────────────

bool _globMatch(String pattern, String text) {
  // Convert a simple glob to a RegExp.
  final buf = StringBuffer('^');
  for (var i = 0; i < pattern.length; i++) {
    final c = pattern[i];
    switch (c) {
      case '*':
        buf.write('.*');
      case '?':
        buf.write('.');
      case '.':
      case '+':
      case '(':
      case ')':
      case '[':
      case ']':
      case '{':
      case '}':
      case '|':
      case '^':
      case r'$':
      case r'\':
        buf.write(r'\' + c);
      default:
        buf.write(c);
    }
  }
  buf.write(r'$');
  return RegExp(buf.toString()).hasMatch(text);
}