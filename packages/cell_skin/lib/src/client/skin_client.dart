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
import '../wire/wire_message.dart';
import 'skin_error.dart';

export 'skin_error.dart';

/// The in-process client over a [SkinMembrane].
///
/// ### When to use
/// * Dart code inside the same process — the demo's scripted agent uses
///   exactly this client, not a mock transport.
///
/// ### How it works
/// [SkinClient.apply] emits a [WireRequest] through
/// [SkinMembrane.request] and returns the outcome (`null` means the
/// response was `pendingReceipt`); [SkinClient.observe] filters the
/// membrane's stream down to [WireStateChange].
///
/// ### Non-obvious
/// The client never fabricates receipts: a `null` outcome means the
/// authoritative receipt arrives with the ledger entry.
///
/// ### See also
/// [RemoteCellClient] (the cell-shaped facade), [RestAdapter] (the
/// socket transport).
///
/// ### AI Agent Guide
/// **Layer:** Skin — the trusted in-process caller, not a transport.
/// **When to use:** a script, test, or agent drives the membrane from Dart; the demo pattern is this client, never a fake.
/// **When NOT to use:** cross-process calls — use `RestAdapter`; cell-shaped remote views — use [RemoteCellClient].
/// **Live signature:** `SkinClient({required SkinMembrane membrane})` with `Future<ApplyOutcome<Object?>?> apply(String cellId, String function, {List<Object?>? positional, Map<String, Object?>? named, int? lastSeenSeq, PulseContext? context})` — pinned at `cell_skin: 0.1.0`
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
  int _correlationCounter = 0;

  SkinClient({required this.membrane});

  String _nextCorrelationId() =>
      'skin-${DateTime.now().microsecondsSinceEpoch}-${_correlationCounter++}';

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
  Future<ApplyOutcome<Object?>?> apply(
    String cellId,
    String function, {
    List<Object?>? positional,
    Map<String, Object?>? named,
    int? lastSeenSeq,
    String type = SkinPulseTypes.restApplyRequest,
    PulseContext? context,
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
    final message =
        await membrane.request(request, type: type, context: context);
    return switch (message) {
      WireResponse response => response.outcome,
      WireError error => throw SkinError(error.code, error.message),
      _ => throw SkinError('unexpected_response', '$message'),
    };
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
