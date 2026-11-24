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

/// The raw data extracted from the transport layer before identity is resolved.
///
/// In the framework's biological metaphor, [SkinCredentials] represent the
/// **Environmental Markers** attached to an incoming signal. They are the
/// raw chemical signatures arriving at the **Skin Membrane** that must be
/// analyzed by [SkinAuth] before a **Command Journey** can be authorized.
///
/// ### When to use
/// - **Transport Adapters**: Used by components like `RestAdapter` or `McpAdapter`
///   to package headers, tokens, and peer metadata for authentication.
/// - **Custom Auth**: Provided as the input to [SkinAuth.authenticate] to
///   determine which [SkinPrincipal] is attempting to influence the graph.
///
/// ### How it works
/// 1. **Signal Ingress**: A request hits the physical transport (e.g., HTTP).
/// 2. **Marker Extraction**: The adapter pulls the bearer token and
///    headers into this structure.
/// 3. **Identity Analysis**: The credentials are passed to the
///    **Identity Gatekeeper** ([SkinAuth]) to resolve the caller's "DNA."
///
/// ### Non‑obvious behavior
/// - **Pre-Somatic**: This data exists entirely outside the reactive graph.
///   It is not recorded in the **Forensic Ledger** unless the [ContextBridge]
///   explicitly maps these markers into the resulting [Context].
/// - **Volatility**: These credentials are transient and should be
///   discarded as soon as the [SkinPrincipal] is resolved to prevent
///   credential leakage within the somatic cells.
///
/// ### See also
/// - [SkinAuth]: The processor that turns these credentials into an identity.
/// - [SkinPrincipal]: The resolved identity resulting from these credentials.
///
/// ### AI Agent Guide
/// **Layer:** Skin — raw transport data.
/// **Live signature:** `final class SkinCredentials { final String? token; final Map<String, Object?> metadata; const SkinCredentials({String? token, Map<String, Object?> metadata = const {}}); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Traceability:** Not ledgered by default; purely for the membrane's identity check.
/// **Security:** Contains sensitive tokens; do not log or pass into the core graph.
final class SkinCredentials {
  /// The specific authentication marker, such as a Bearer token.
  ///
  /// In the framework's biological metaphor, this is the **Membrane Key**.
  /// It is the primary credential used to bypass the membrane's initial
  /// rejection gate.
  final String? token;

  /// The technical metadata surrounding the signal's arrival.
  ///
  /// In the framework's biological metaphor, these are the **Transport Echoes**.
  /// They include information like the peer address, user agent, or
  /// custom headers that provide context for the [SkinAuth] process.
  final Map<String, Object?> metadata;

  /// Creates a new [SkinCredentials] envelope for membrane analysis.
  ///
  /// Assembles the raw **Environmental Markers** required for the
  /// system to identify the source of an incoming **Nervous Signal**.
  const SkinCredentials({this.token, this.metadata = const {}});
}

/// The resolved identity DNA of an external actor at the membrane.
///
/// In the framework's biological metaphor, [SkinPrincipal] is the **Resolved
/// Identity DNA**. It represents the stable chemical signature of an actor
/// after their **Environmental Markers** ([SkinCredentials]) have been
/// verified by the **Identity Gatekeeper** ([SkinAuth]).
///
/// This identity is the source of all **Provenance**. Before a **Nervous Signal**
/// can begin a **Command Journey** into the somatic graph, the [ContextBridge]
/// translates this principal into an internal framework `Context`.
///
/// ### When to use
/// - **Auth Result**: The primary return type for [SkinAuth.authenticate].
/// - **Identity Mapping**: Used by the [ContextBridge] to determine what level
///   of authority to grant to the resulting pulse.
///
/// ### How it works
/// 1. **Verification**: [SkinAuth] validates the incoming credentials.
/// 2. **Identification**: This class is instantiated with the actor's
///    unique [id] and [roles].
/// 3. **Translation**: The membrane passes this principal to the bridge,
///    which stamps the pulse with somatic authority.
///
/// ### Non‑obvious behavior
/// - **Forensic Persistence**: The [id] provided here is what ultimately
///   appears in the **Forensic Ledger**. Choosing a stable, unique ID is
///   critical for long-term audit integrity.
/// - **Skin-Only Boundary**: Somatic cells (the core graph) never interact
///   with [SkinPrincipal] directly. They only see the `Context` produced
///   by the **Membrane Translator**.
/// - **Anonymity**: If no identity is provided, the system defaults to
///   the **Neutral Signature** ([SkinPrincipal.anonymous]).
///
/// ### See also
/// - [SkinAuth]: The gatekeeper that produces this identity.
/// - [ContextBridge]: The translator that turns this principal into somatic authority.
/// - [WireLedgerEntry]: Where this identity eventually leaves a forensic mark.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the "Who" at the boundary.
/// **Live signature:** `final class SkinPrincipal { final String id; final List<String> roles; final Map<String, Object?> claims; const SkinPrincipal({required String id, List<String> roles = const [], Map<String, Object?> claims = const {}}); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Traceability:** The `id` is the key for all forensic lookups.
/// **Constraint:** Roles here do not grant power; they are data points for
/// the `ContextBridge` to use when assigning authority.
final class SkinPrincipal {
  /// The stable identifier for the actor.
  ///
  /// In the framework's biological metaphor, this is the **Identity Anchor**.
  /// It is the authoritative string that will be written into the
  /// **Forensic Ledger** to attribute a **Somatic State Transition**.
  final String id;

  /// The list of somatic permissions or categories assigned to the actor.
  ///
  /// In the framework's biological metaphor, these are the **Identity Traits**.
  /// They are used by the [ContextBridge] and various **Integrity Gates**
  /// to decide if a **Command Journey** is permitted to mutate a specific cell.
  final List<String> roles;

  /// Additional metadata and claims associated with the identity.
  ///
  /// In the framework's biological metaphor, these are the **Extended Signatures**.
  /// They provide the **Membrane Translator** with extra context (e.g.,
  /// organization ID, session expiration) to refine the internal `Context`.
  final Map<String, Object?> claims;

  /// Creates a new [SkinPrincipal] with an authoritative identity.
  ///
  /// Assembles the **Resolved Identity DNA** required for a signal to
  /// be authorized at the **Skin Membrane**.
  const SkinPrincipal({
    required this.id,
    this.roles = const [],
    this.claims = const {},
  });

  /// The unauthenticated identity used when no specific credentials are provided.
  ///
  /// In the framework's biological metaphor, this is the **Neutral Signature**.
  /// It represents a signal with no verified provenance, usually resulting
  /// in a **Membrane Rejection** unless the target cell is explicitly
  /// marked for public exposure.
  const SkinPrincipal.anonymous()
      : id = 'anonymous',
        roles = const [],
        claims = const {};
}


/// The gatekeeper responsible for identifying external actors at the membrane.
///
/// In the framework's biological metaphor, [SkinAuth] is the **Identity Gatekeeper**.
/// It sits at the entry point of the **Skin Membrane** and analyzes the
/// **Environmental Markers** ([SkinCredentials]) attached to an incoming
/// **Nervous Signal**.
///
/// Its sole responsibility is to resolve the caller's "Who"—transforming raw
/// transport markers into the **Resolved Identity DNA** ([SkinPrincipal])
/// required to begin a **Command Journey**.
///
/// ### When to use
/// - **Identity Resolution**: Implement this to define how your system
///   verifies tokens, API keys, or peer identities.
/// - **Adapter Configuration**: Required when binding a `RestAdapter` or
///   `McpAdapter`, as the membrane requires an explicit gatekeeper to
///   establish provenance.
///
/// ### How it works
/// 1. **Signal Arrival**: A request hits the physical transport layer.
/// 2. **Verification**: The [authenticate] method inspects the credentials.
/// 3. **Identity Resolution**: If valid, it returns a [SkinPrincipal]. If
///    invalid, it returns `null`, triggering an immediate **Membrane Rejection**.
/// 4. **Provenance Flow**: The resulting principal is passed to the
///    [ContextBridge] to be translated into internal somatic authority.
///
/// ### Non‑obvious behavior
/// - **Authentication != Authorization**: This interface only identifies the
///   actor. The decision to allow or reject a specific **Somatic State Transition**
///   is handled deeper in the graph by a cell's **Integrity Gate**.
/// - **Forensic Impact**: The identity resolved here is what eventually
///   appears in the **Forensic Ledger**. A failure here prevents a
///   **Forensic Receipt** from ever being generated.
/// - **Async Nature**: Verification often requires external lookups (e.g.,
///   a database or OIDC provider), so the process is asynchronous.
///
/// ### See also
/// - [SkinCredentials]: The raw markers provided to this gatekeeper.
/// - [SkinPrincipal]: The identity DNA produced by this gatekeeper.
/// - [ContextBridge]: The next step in the journey, translating identity to authority.
///
/// ### AI Agent Guide
/// **Layer:** Skin — the credential check, not the authorisation policy (the domain's `TestCell` decides).
/// **When to use:** a requirement says "authenticate REST callers", "per-principal context", or "bearer tokens".
/// **When NOT to use:** authorisation decisions — return the principal and let the graph's gates decide.
/// **Live signature:** `abstract interface class SkinAuth { Future<SkinPrincipal?> authenticate(SkinCredentials credentials); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
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

  /// Analyzes **Environmental Markers** to resolve a **Resolved Identity DNA**.
  ///
  /// In the framework's biological metaphor, this method performs
  /// **Identity Analysis**. It inspects the **Membrane Key** (token) and
  /// **Transport Echoes** (metadata) to determine if the signal has a
  /// verifiable source.
  ///
  /// Returns a [SkinPrincipal] if the identity is verified, or `null` if the
  /// markers are unrecognized or invalid, resulting in a rejection.
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials);
}

/// A permissive gatekeeper that accepts all incoming signals without verification.
///
/// In the framework's biological metaphor, [AllowAllSkinAuth] is the
/// **Universal Receptor**. It allows any **Nervous Signal** (request) to cross
/// the **Skin Membrane** by assigning it the **Neutral Signature**
/// ([SkinPrincipal.anonymous]).
///
/// ### When to use
/// - **Testing & Demos**: The standard choice for loopback tests or local
///   demonstrations where identity verification is not required.
/// - **Public Exposure**: Use this for systems intended to be entirely
///   open to the environment, where authorization is handled solely by
///   the downstream **Integrity Gates** based on the target cell.
///
/// ### How it works
/// 1. **Signal Ingress**: A request arrives at the membrane.
/// 2. **Blind Acceptance**: This gatekeeper ignores all **Environmental Markers**
///    (tokens, metadata) within the [SkinCredentials].
/// 3. **Anonymous Resolution**: It returns [SkinPrincipal.anonymous],
///    ensuring the journey can proceed to the [ContextBridge].
///
/// ### Non‑obvious behavior
/// - **Deliberate Opt-in**: This is never the default. Adapters like `RestAdapter`
///   require an explicit `auth` parameter; passing this class is a conscious
///   decision to disable identity-based rejection at the membrane.
/// - **Forensic Impact**: Every **Somatic State Transition** triggered through
///   this gate will be recorded in the **Forensic Ledger** under the
///   ID `'anonymous'`. This makes individual actor attribution impossible.
/// - **Integrity Gates Still Apply**: Authenticating a signal as anonymous
///   does not grant it power. If a target cell requires a `SystemContext`
///   or a specific role, the pulse will still be rejected by the cell's
///   internal **Integrity Gate**.
///
/// ### See also
/// - [SkinPrincipal.anonymous]: The identity DNA produced by this class.
/// - [SkinAuth]: The base interface for identity gatekeepers.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is a "pass-through" identity check.
/// **Live signature:** `final class AllowAllSkinAuth implements SkinAuth { const AllowAllSkinAuth(); Future<SkinPrincipal?> authenticate(SkinCredentials credentials); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Status:** All signals are marked anonymous.
/// **Security:** Use only in non-production or intentionally public environments.
final class AllowAllSkinAuth implements SkinAuth {
  /// Creates a new [AllowAllSkinAuth] gatekeeper.
  ///
  /// In the framework's biological metaphor, this initializes a
  /// **Universal Receptor** for the membrane.
  const AllowAllSkinAuth();

  /// Resolves every impulse to a **Neutral Signature**.
  ///
  /// This method performs a **Blind Analysis**. It completely ignores
  /// the **Membrane Key** (token) and **Transport Echoes** (metadata),
  /// providing an immediate [SkinPrincipal.anonymous] to allow the
  /// **Command Journey** to begin.
  @override
  Future<SkinPrincipal?> authenticate(SkinCredentials credentials) async =>
      const SkinPrincipal.anonymous();
}
