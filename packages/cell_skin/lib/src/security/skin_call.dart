// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The ambient call the domain can see.
///
/// `Cell.apply` does not take a context, and a `TestCell.action` does not
/// receive the request pulse. [SkinCall] installs a zone around the
/// target apply instead — the same pattern as the framework's own
/// `LedgerScope` — so the domain gate and the binding body can read who
/// called, with what pulse context, on the same call stack as `apply`,
/// including after an `await`.
///
/// The recorded ledger pulse is a separate concern: the row stores the
/// pulse the binding returns. [SkinPulses] stamps that pulse with the
/// call's context, so `PulseCodec` stores the actor and replay restores
/// it.
/// {@category Features}
/// {@category Auth & Provenance}
library;

import 'dart:async';
import 'dart:convert';

import 'package:cell/cell.dart';

import 'skin_auth.dart';

/// The ambient context of one membrane apply.
///
/// ### When to use
/// A domain `TestCell.action` reads [SkinCall.current] (or the [PulseContext]
/// carried here) to see who is driving the apply before the function body
/// runs. A binding body may read it too. The value is `null` outside a
/// membrane apply.
///
/// ### How it works
/// The router wraps the target apply in [SkinCall.run] — inside the
/// ledger scope when the router opens one. `Zone.fork` keeps parent zone
/// values it does not override, so the `LedgerScope` survives when the
/// caller already entered `graph.run`.
///
/// ### Non-obvious
/// Replay reconstructs the stored pulse and routes it through the
/// receptor; it does not enter a `SkinCall` zone. A gate that decides
/// only by reading [SkinCall.current] sees `null` on replay — the stored
/// actor is the audit record. Gates that must keep refusing on replay
/// keep checking the value (`ValueGate`, a door gate on the pulse
/// payload).
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the "who called" zone, not an authorization
/// decision.
/// **When to use:** a domain gate must know the caller during `apply`;
/// a binding must read the caller after an `await`.
/// **When NOT to use:** replay-time authorization — replay does not
/// enter this zone; stored actors are the audit record.
/// **Live signature:** `final class SkinCall { final SkinPrincipal? principal; final PulseContext pulseContext; final DateTime? deadline; static SkinCall? get current; static FutureOr<T> run<T>(SkinCall call, FutureOr<T> Function() body); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
final class SkinCall {
  /// The authenticated caller, or `null` for an in-process request whose
  /// context carried no principal snapshot.
  final SkinPrincipal? principal;

  /// The request's pulse context — the actor the ledger will store when
  /// the binding's pulse is stamped.
  final PulseContext pulseContext;

  /// The instant after which a queued request must not start.
  ///
  /// Copied from the request by the router (the membrane stamps
  /// `now + maxQueueWait` — or the caller's earlier deadline — on every
  /// emit). `null` when the membrane was opened with `Duration.zero`
  /// and the caller passed no deadline.
  final DateTime? deadline;

  /// Creates an ambient call record.
  const SkinCall({
    this.principal,
    required this.pulseContext,
    this.deadline,
  });

  static final Object _key = Object();

  /// The call currently installed around the apply, or `null` outside a
  /// membrane apply.
  static SkinCall? get current => Zone.current[_key] as SkinCall?;

  /// Runs [body] in a child zone that carries [call].
  ///
  /// [body] is **not** wrapped in a fresh `async` closure: `Zone.run` on
  /// a closure that returns a `Future` already binds that future's
  /// continuations to the zone, so the call survives an `await` inside
  /// the body.
  static FutureOr<T> run<T>(SkinCall call, FutureOr<T> Function() body) {
    return Zone.current.fork(zoneValues: {_key: call}).run(body);
  }
}

/// Builds a [Pulse] for a state change, stamped with the current
/// [SkinCall]'s context when one is active.
///
/// * Bare values become a governed pulse carrying the call's
///   [PulseContext] — that context is what the ledger stores and what
///   replay restores.
/// * A pulse whose `context.actor` is already non-empty is left alone.
/// * A pulse with no actor (a bare `Pulse(value)`) is re-stamped with
///   the call's context.
abstract final class SkinPulses {
  /// Stamps [value] with the ambient call's context, or returns a bare
  /// pulse when no [SkinCall] is active.
  static Pulse<T> payload<T>(T value) {
    final call = SkinCall.current;
    if (call == null) return Pulse<T>(value);
    return Pulse<T>.governed(payload: value, context: call.pulseContext);
  }

  /// Returns [pulse] unchanged when it already carries an actor, and a
  /// governed copy stamped with the ambient call's context otherwise.
  static Pulse<T> stamp<T>(Pulse<T> pulse) {
    final actor = pulse.context.actor;
    if (actor != null && actor.isNotEmpty) return pulse;
    final call = SkinCall.current;
    if (call == null) return pulse;
    return Pulse<T>.governed(payload: pulse.payload, context: call.pulseContext);
  }
}

/// The request `PulseContext` a transport builds for an authenticated
/// caller.
///
/// The actor is `skin:<principal id>` (`alice` becomes `skin:alice`;
/// `anonymous` becomes `skin:anonymous` — the id is used as-is, never
/// stripped or stacked). A JSON snapshot of the principal — id, roles,
/// and the claims `jsonEncode` accepts — rides in `others` under
/// `skin.principal`, so the router can rebuild the principal for
/// `SkinCall` and an authorizer. The bearer token is never copied.
PulseContext skinPulseContext({
  required SkinPrincipal principal,
  required Context baseContext,
  required String reason,
}) =>
    PulseContext(
      baseContext: baseContext,
      actor: 'skin:${principal.id}',
      reason: reason,
      others: {'skin.principal': _encodableSnapshot(principal)},
    );

Map<String, Object?> _encodableSnapshot(SkinPrincipal principal) {
  final claims = <String, Object?>{};
  principal.claims.forEach((key, value) {
    try {
      jsonEncode(value);
      claims[key] = value;
    } catch (_) {
      // A claim JSON cannot encode is left off the snapshot. It stays on
      // the live principal the transport holds.
    }
  });
  return {'id': principal.id, 'roles': principal.roles, 'claims': claims};
}

/// The JSON snapshot of a [SkinPrincipal] for a request context's
/// `others` under `skin.principal`: id, roles, and the claims
/// `jsonEncode` accepts. The bearer token is never part of it.
Map<String, Object?> skinPrincipalSnapshot(SkinPrincipal principal) =>
    _encodableSnapshot(principal);

/// Rebuilds a [SkinPrincipal] from the snapshot stored in a
/// [PulseContext]'s `others` (`skin.principal`). A missing or malformed
/// snapshot yields `null` — it never throws.
SkinPrincipal? principalFrom(PulseContext context) {
  final others = context.others;
  final raw = others?['skin.principal'];
  if (raw is! Map) return null;
  final id = raw['id'];
  if (id is! String) return null;
  final roles = raw['roles'];
  final claims = raw['claims'];
  return SkinPrincipal(
    id: id,
    roles: roles is List ? roles.whereType<String>().toList() : const [],
    claims: claims is Map
        ? {
            for (final entry in claims.entries)
              if (entry.key is String) entry.key as String: entry.value,
          }
        : const {},
  );
}
