// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The in-process skin client.
///
/// `SkinClient` speaks the same wire protocol as the REST adapter —
/// `WireRequest` in, `WireResponse` / `WireError` out — but skips the
/// sockets and talks to the membrane's four Cells directly. Downstream
/// code that already speaks `Cell.apply` can consume a remote graph
/// through it unchanged (see [RemoteCellClient]).
/// {@category Features}
library;

import 'package:cell/cell.dart';

import '../cells/skin_membrane.dart';
import '../manifest/skin_manifest.dart';
import '../security/context_bridge.dart';
import '../security/skin_auth.dart';
import '../security/skin_call.dart';
import '../wire/correlation_id.dart';
import '../wire/wire_message.dart';
import 'skin_error.dart';

export 'skin_error.dart';

/// The authoritative in-process coordinator for stimulating the somatic graph.
///
/// In the framework's biological metaphor, [SkinClient] is the **Internal
/// Axonal Conduit**. It allows local logic (such as scripts, tests, or
/// orchestrators) to initiate a **Command Journey** that passes through
/// the **Skin Membrane** without the overhead of physical transport pores
/// like REST or MCP.
///
/// Despite being in-process, it speaks the same **Nervous Signal** vocabulary
/// ([WireRequest], [WireResponse], [WireError]) as external adapters. This
/// ensures that the **Forensic Ledger** treats internal impulses with the
/// same rigor and traceability as those arriving from the environment.
///
/// ### When to use
/// - **Scripted Agents**: The primary way to drive a membrane from within
///   the same Dart process (e.g., in-process AI agents or CLI tools).
/// - **Integration Testing**: Use this to verify **Integrity Gates** and
///   **Somatic State Transitions** without spinning up network sockets.
/// - **Orchestration**: Ideal for `cell_flow` components that need to
///   act as trusted participants in the somatic graph.
///
/// ### How it works
/// 1. **Signal Ingress**: [apply] wraps local arguments into a [WireRequest].
/// 2. **Membrane Crossing**: The signal is injected into [SkinMembrane.request].
/// 3. **Forensic Resolution**: The client awaits a **Forensic Receipt**.
///    Successful transitions return an `ApplyOutcome`; rejections at the
///    membrane throw a [SkinError].
///
/// ### Non‑obvious behavior
/// - **Authoritative Outcome**: The client never fabricates receipts. If
///   the membrane returns a `pendingReceipt`, this client returns `null`,
///   indicating that the **Forensic Ledger Row** will arrive later via
///   the [ledger] stream.
/// - **Integrity Enforcement**: Even though the caller is in-process, the
///   [SkinRouter] still enforces cursor checks and schema validation,
///   preventing "Forensic Ambiguity."
///
/// ### AI Agent Guide
/// **Layer:** Skin — the trusted in-process caller, not a transport.
/// **When to use:** a script, test, or agent drives the membrane from Dart; the demo pattern is this client, never a fake.
/// **When NOT to use:** cross-process calls — use `RestAdapter`; cell-shaped remote views — use [RemoteCellClient].
/// **Live signature:** `SkinClient({required SkinMembrane membrane})` with `Future<ApplyOutcome<Object?>?> apply(String cellId, String function, {List<Object?>? positional, Map<String, Object?>? named, int? lastSeenSeq, String type = SkinPulseTypes.restApplyRequest, PulseContext? context, SkinPrincipal? principal})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Do NOT confuse with:** `RemoteCellClient` (remote facade) or `RestAdapter` (HTTP server).
/// **Guide:** `FEATURES-Skin.md` §12 (clients).
/// **Example:** `example/lib/mock/mock_agent.dart` (every scripted beat).
/// **Cross-layer:** the returned outcome is the domain cell's own `ApplyOutcome` — including its real `ApplyRejected`.
/// **Minimal compilable example**
/// ```dart
/// final client = SkinClient(membrane: membrane);
/// final outcome = await client.apply(
///   'thermostat', 'setTarget', positional: [21]);
/// ```
final class SkinClient {
  final SkinMembrane membrane;

  SkinClient({required this.membrane});

  String _nextCorrelationId() => nextCorrelationId('skin');

  /// Invokes `(cellId, function)` through the membrane and returns the
  /// target's real [ApplyOutcome].
  ///
  /// Returns `null` when the response was `pendingReceipt` (the state
  /// change was observed but its ledger entry had not landed — the
  /// authoritative receipt arrives on the ledger stream).
  ///
  /// Throws [SkinError] for exposure-gate misses, cursor conflicts, and
  /// bad arguments; those rejections produced no receipt.
  ///
  /// [context] stamps this request's provenance on the emitted pulse.
  /// [principal] is the in-process caller: without a [context] the
  /// request context is built through `skinPulseContext` (a
  /// `DescribeContextBridge` base plus `skin:<id>` actor and a JSON
  /// snapshot the router reads back into `SkinCall.principal`); with a
  /// [context] that context is used as-is and the snapshot inside its
  /// `others` (when present) wins.
  Future<ApplyOutcome<Object?>?> apply(
    String cellId,
    String function, {
    List<Object?>? positional,
    Map<String, Object?>? named,
    int? lastSeenSeq,
    String type = SkinPulseTypes.restApplyRequest,
    PulseContext? context,
    SkinPrincipal? principal,
  }) async {
    final request = WireRequest(
      cellId: cellId,
      function: function,
      positional: positional == null
          ? null
          : {for (var i = 0; i < positional.length; i++) '$i': positional[i]},
      named: named,
      correlationId: _nextCorrelationId(),
      lastSeenSeq: lastSeenSeq,
    );
    final requestContext = context ??
        (principal == null
            ? null
            : skinPulseContext(
                principal: principal,
                baseContext: const DescribeContextBridge().resolve(principal),
                reason: 'skin apply $cellId.$function',
              ));
    final message = await membrane.request(
      request,
      type: type,
      context: requestContext,
      principal: principal,
    );
    return switch (message) {
      WireResponse response => outcomeOf(response),
      WireError error => throw SkinError(error.code, error.message),
      _ => throw SkinError('unexpected_response', '$message'),
    };
  }

  /// The live outcome a [WireResponse] carries, with honest `null` and
  /// error handling.
  ///
  /// `null` is returned only for `pendingReceipt` — the state change was
  /// observed but its ledger entry had not landed. A replay from a
  /// durable idempotency store may carry only [WireResponse.outcomeJson]
  /// (the live object cannot survive a restart); returning `null` for
  /// that would masquerade as `pendingReceipt`, so it throws instead.
  /// Fabricating a live outcome from JSON would invent a receipt, which
  /// the skin never does — use [SkinMembrane.request] to read
  /// `outcomeJson` when only the wire form exists.
  static ApplyOutcome<Object?>? outcomeOf(WireResponse response) {
    if (response.outcome != null) return response.outcome;
    if (response.pendingReceipt || response.outcomeJson == null) return null;
    throw SkinError(
      'outcome_json_only',
      'the stored outcome survived only as wire JSON (a durable '
      'idempotency store replay); use SkinMembrane.request to read '
      'outcomeJson',
    );
  }

  /// Fetches the current tool catalogue.
  Future<SkinManifest> manifest() async {
    final message = await membrane.request(
      const WireManifestRequest(),
      type: SkinPulseTypes.manifestRequest,
    );
    return switch (message) {
      WireManifestResponse response => response.manifest,
      WireError error => throw SkinError(error.code, error.message),
      _ => throw SkinError('unexpected_response', '$message'),
    };
  }

  /// Verifies the membrane's ledger (requires a bound ledger).
  Future<void> verify() async {
    final ledger = membrane.ledger;
    if (ledger == null) {
      throw const SkinError('no_ledger', 'the membrane has no bound ledger');
    }
    await ledger.verify();
  }

  /// The full outbound pulse stream (responses, egress, ledger, errors).
  Stream<Pulse<WireMessage>> get events => membrane.responses;

  /// State-change pulses for one cell (`skin.egress.<cellId>` carrying
  /// [WireStateChange]).
  Stream<Pulse<WireMessage>> observe(String cellId) =>
      membrane.responses.where((pulse) =>
          pulse.type == '${SkinPulseTypes.egressPrefix}$cellId' &&
          pulse.payload is WireStateChange);

  /// Ledger entries after [since] (inclusive of nothing older).
  Stream<Pulse<WireMessage>> ledger({int since = -1}) =>
      membrane.responses.where((pulse) =>
          pulse.payload is WireLedgerEntry &&
          (pulse.payload as WireLedgerEntry).entry.seq > since);
}
