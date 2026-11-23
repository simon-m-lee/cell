// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The authentication SPI.
///
/// The skin enforces no unified authorization language — the two gates
/// (exposure + the target's `TestCell.action`) stay the only gates.
/// `SkinAuth` only answers *who* is on the other end of the transport;
/// the [ContextBridge] then translates that identity into the
/// framework's own provenance type before pulses enter the graph.
/// {@category Features}
library;

/// Transport-level credentials.
final class SkinCredentials {
  /// Bearer token, when the transport carries one.
  final String? token;

  /// Transport metadata (headers, peer address, …).
  final Map<String, Object?> metadata;

  const SkinCredentials({this.token, this.metadata = const {}});
}

/// The authenticated identity behind a request.
final class SkinPrincipal {
  /// Stable principal id.
  final String id;

  /// Roles carried by the principal.
  final List<String> roles;

  /// Free-form claims.
  final Map<String, Object?> claims;

  const SkinPrincipal({
    required this.id,
    this.roles = const [],
    this.claims = const {},
  });

  /// The unauthenticated principal used when no [SkinAuth] is
  /// configured.
  const SkinPrincipal.anonymous()
      : id = 'anonymous',
        roles = const [],
        claims = const {};
}

/// Authenticates transport credentials. Returns `null` to reject.
///
/// ### When to use
/// * Implementing the adapter's credential check — `RestAdapter.bind`
///   requires a [SkinAuth]; there is no unauthenticated default.
///
/// ### How it works
/// [authenticate] receives [SkinCredentials] (token plus transport
/// metadata such as peer, host, and user agent) and returns a
/// [SkinPrincipal] whose id, roles, and claims flow into the
/// per-request `PulseContext` through the [ContextBridge].
///
/// ### Non-obvious
/// A `null` result means 401 with `WWW-Authenticate`; the principal is
/// never discarded — it becomes the request's provenance.
///
/// ### See also
/// [SkinCredentials], [SkinPrincipal], [ContextBridge].
///
/// ### AI Agent Guide
/// **Layer:** Skin — the credential check, not the authorisation policy (the domain's `TestCell` decides).
/// **When to use:** a requirement says "authenticate REST callers", "per-principal context", or "bearer tokens".
/// **When NOT to use:** authorisation decisions — return the principal and let the graph's gates decide.
/// **Live signature:** `abstract interface class SkinAuth { Future<SkinPrincipal?> authenticate(SkinCredentials credentials); }` — pinned at `cell_skin: 0.1.0`
/// **Do NOT confuse with:** `ContextBridge` (principal → framework `Context`) or `SkinWhitelist` (exposure policy, not identity).
/// **Guide:** `FEATURES-Skin.md` §13 (security SPI).
/// **Example:** `example/lib/mock/rest_io.dart` (the demo opts into `AllowAllSkinAuth`).
/// **Cross-layer:** `RestAdapter` stamps `PulseContext(baseContext: bridge.resolve(principal), actor: 'skin:<id>')` per request.
/// **Minimal compilable example**
/// ```dart
/// final class TokenAuth implements SkinAuth {
///   @override
///   Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async =>
///       credentials.token == 'secret'
///           ? const SkinPrincipal(id: 'tester')
///           : null;
/// }
/// ```
/// {@category Auth & Provenance}
abstract interface class SkinAuth {
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials);
}

/// An auth implementation that accepts everyone — the explicit
/// anonymous opt-in for a loopback-only demo or test adapter.
///
/// ### Non-obvious
/// This is **not** a default: `RestAdapter.bind` requires an explicit
/// `auth:` argument, and passing this class is the deliberate choice
/// to accept anonymous callers.
final class AllowAllSkinAuth implements SkinAuth {
  const AllowAllSkinAuth();

  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async =>
      const SkinPrincipal.anonymous();
}
