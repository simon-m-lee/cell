// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The application's one authorization hook.
///
/// Authentication (who is calling) already happened at the transport —
/// the REST adapter's `SkinAuth` produced a [SkinPrincipal], and the
/// adapter stamped it onto the request context. The [SkinAuthorizer]
/// decides *whether this principal may apply this binding*. Roles stay
/// data: the skin never reads them.
/// {@category Security}
library;

import '../binding/skin_binding.dart';
import 'skin_auth.dart';

/// Decides whether [principal] may apply [binding].
///
/// `null` on the membrane means allow, and the function is not
/// invoked. Returning `false` answers `forbidden` (HTTP 403) and the
/// binding's function does not run; the denial is not cached, so a
/// later call by an allowed principal is a new apply. A throw is a
/// `transport_error` and the function still does not run.
///
/// The hook is called only after the binding was found and the
/// whitelist allows it — a hidden tool stays `unknown_tool` and is
/// never offered to the hook. It runs on the serial router, before
/// schema, cursor, and `apply`; a slow hook holds the queue.
///
/// The hook decides **applies only**. The read surfaces — `GET
/// /skin/manifest`, `/skin/observe/:cellId`, `/skin/ledger`, and
/// `/skin/verify` — are gated by authentication plus the whitelist's
/// exposure, never by this hook; they are all-or-nothing per
/// authenticated peer. An idempotency hit (same actor, same body,
/// within the store's TTL) replays the stored outcome without running
/// the hook again: a revocation inside the TTL does not stop the
/// cached echo, and a stored post-commit failure keeps echoing its
/// error.
///
/// The hook receives the [SkinPrincipal] the router parsed from the
/// request context. It may read any field of that principal — the skin
/// itself does not.
///
/// ### AI Agent Guide
/// **Layer:** Skin — the application's authorization decision, not a
/// credential check.
/// **When to use:** a BRD says "forbid this principal", "only operators
/// may run this binding", or "this cell is read-only for guests".
/// **When NOT to use:** authentication (the transport's `SkinAuth`
/// already answered *who*), or a role table inside `cell_skin`.
/// **Live signature:** `typedef SkinAuthorizer = Future<bool> Function(SkinPrincipal principal, SkinBinding binding);` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Do NOT confuse with:** `SkinAuth.authenticate` (who is calling) or
/// `SkinWhitelist` (which bindings exist on the wire).
/// **Guide:** `HowTo-Auth.md` (authorize with one hook),
/// `ARCHITECTURE-Skin.md` §5.
typedef SkinAuthorizer = Future<bool> Function(
  SkinPrincipal principal,
  SkinBinding binding,
);
