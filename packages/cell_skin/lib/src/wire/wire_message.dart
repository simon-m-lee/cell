// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The wire message taxonomy for `cell_skin`.
///
/// One wire event. Every transport — MCP, REST, SSE, stdio — is a
/// `Pulse<WireMessage>` whose `type` discriminates the variant. The
/// payload classes themselves are plain JSON-serialisable objects; the
/// pulse's own `type`, `context`, `source` and `trace` fields carry
/// everything else, so no new envelope codec exists on top of the
/// framework's `PulseCodec`.
/// {@category Features}
library;

import 'package:cell/cell.dart';

import '../manifest/skin_manifest.dart';
import 'wire_outcome.dart';
import 'wire_receipt.dart';

/// Pulse-type naming convention for the wire. Values follow the plan's
/// taxonomy; no new type system is introduced — these are `Pulse.type`
/// strings.
abstract final class SkinPulseTypes {
  static const mcpToolsCall = 'mcp.tools.call';
  static const restApplyRequest = 'rest.apply.request';
  static const mcpToolsResultPrefix = 'mcp.tools.result.';
  static const restApplyResponsePrefix = 'rest.apply.response.';
  static const mcpNotificationPrefix = 'mcp.notifications.';
  static const manifestRequest = 'skin.manifest.request';
  static const manifestResponse = 'skin.manifest.response';
  static const ledgerEntry = 'skin.ledger.entry';
  static const egressPrefix = 'skin.egress.';
  static const errorTransport = 'skin.error.transport';

  /// `mcp.tools.result.{accepted,rejected,staged}` for [outcome].
  static String resultType(ApplyOutcome<Object?> outcome) =>
      '$mcpToolsResultPrefix${switch (outcome) {
        ApplyAccepted() => 'accepted',
        ApplyRejected() => 'rejected',
        ApplyStaged() => 'staged',
      }}';

  /// `rest.apply.response.{accepted,rejected,staged}` for [outcome].
  static String restResponseType(ApplyOutcome<Object?> outcome) =>
      '$restApplyResponsePrefix${switch (outcome) {
        ApplyAccepted() => 'accepted',
        ApplyRejected() => 'rejected',
        ApplyStaged() => 'staged',
      }}';
}

/// One wire event. Every transport — MCP, REST, SSE, stdio — is a
/// `Pulse<WireMessage>` whose `type` discriminates the variant.
///
/// ### When to use
/// * Emitting or receiving commands, outcomes, state observations, and
///   audit entries across the membrane.
/// * Writing a transport adapter: the sealed hierarchy is the whole
///   wire vocabulary — there is no other envelope.
///
/// ### How it works
/// Each variant carries exactly one intent; [toJson] produces the
/// sanitised wire form and [WireMessage.fromJson] restores it.
/// `correlationId` is server-assigned on requests; egress
/// (`WireStateChange`) deliberately carries no correlation id.
///
/// ### Non-obvious
/// `WireResponse` and `WireError` look alike at a glance, but an error
/// has **no receipt** — it must never masquerade as a response. Egress
/// is `WireStateChange`, never a `WireResponse`.
///
/// ### See also
/// [WireOutcome], [WireReceipt], and [SkinPulseTypes] for the `type`
/// taxonomy.
///
/// {@category Features}
/// {@category Wire Messages}
sealed class WireMessage {
  const WireMessage();

  /// The stable discriminator used by [WireMessage.fromJson].
  String get kind;

  /// JSON-serialisable wire form. Payloads stay JSON-safe; the pulse's
  /// metadata travels on the pulse, not inside this map.
  Map<String, Object?> toJson();

  /// Decodes a [WireMessage] produced by [toJson].
  ///
  /// Throws [FormatException] on an unknown or malformed `kind`, or on
  /// any malformed field — never a raw [TypeError].
  factory WireMessage.fromJson(Map<String, Object?> json) {
    final kind = json['kind'];
    try {
      return switch (kind) {
        'request' => WireRequest.fromJson(json),
        'response' => WireResponse.fromJson(json),
        'stateChange' => WireStateChange.fromJson(json),
        'notification' => WireNotification.fromJson(json),
        'manifestRequest' => const WireManifestRequest(),
        'manifestResponse' => WireManifestResponse.fromJson(json),
        'ledgerEntry' => WireLedgerEntry.fromJson(json),
        'error' => WireError.fromJson(json),
        _ => throw FormatException('unknown wire message kind: $kind'),
      };
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException(
          'malformed wire message (kind: $kind): ${error.runtimeType}');
    }
  }
}

/// An inbound call: invoke [function] on the cell named [cellId].
///
/// ### When to use
/// * Every command that crosses the skin — REST `POST /skin/apply`,
///   an MCP tool call, or a Dart client's `apply`.
///
/// ### How it works
/// The router serialises requests (`concurrency: 1`), validates the
/// argument envelope and declared schema, and calls `target.apply`.
/// [correlationId] is **server-assigned**; [clientCorrelationId] is
/// the caller's echo-only id.
///
/// ### Non-obvious
/// Positional arguments are an index-keyed map (`'0'..'n-1'`,
/// contiguous) so JSON object ordering can never matter; transports
/// may accept a plain JSON array and index it.
///
/// ### See also
/// [SkinBinding], [SkinMembrane.request].
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is a command envelope, not a graph node.
/// **When to use:** sending a command at a bound `(cellId, function)` over any transport.
/// **When NOT to use:** fire-and-forget signals — use [WireNotification]; state observations — use [WireStateChange].
/// **Live signature:** `const WireRequest({required String cellId, required String function, Map<String, Object?>? positional, Map<String, Object?>? named, required String correlationId, String? clientCorrelationId, int? lastSeenSeq})` — pinned at `cell_skin: 0.1.0`
/// **Do NOT confuse with:** `ApplyCommand` (the framework's own command record, built from this by the binding).
/// **Guide:** `ARCHITECTURE-Skin.md` §3 (wire taxonomy) and §6 (correlation).
/// **Example:** `example/lib/mock/mock_agent.dart` (every scripted beat is one request).
/// **Cross-layer:** the target cell's own `TestCell` gate may reject the command after exposure accepts it.
/// **Minimal compilable example**
/// ```dart
/// final request = WireRequest(
///   cellId: 'home.living.thermostat',
///   function: 'setTarget',
///   positional: {'0': 21},
///   correlationId: 'srv-1',
///   clientCorrelationId: 'client-1',
/// );
/// ```
/// {@category Wire Messages}
/// {@category Idempotency}
final class WireRequest extends WireMessage {
  /// The registered graph name of the target cell.
  final String cellId;

  /// The exposed function name inside [cellId]'s binding set.
  final String function;

  /// JSON-decoded positional arguments, or `null` when none were sent.
  final Map<String, Object?>? positional;

  /// JSON-decoded named arguments, or `null` when none were sent.
  final Map<String, Object?>? named;

  /// The server-assigned correlation id. [SkinMembrane.request] matches
  /// responses on this id; transports generate it themselves and carry
  /// the client-chosen id in [clientCorrelationId], so a client can
  /// never hijack another client's pending response.
  final String correlationId;

  /// The client-chosen correlation id, echoed back verbatim — matching
  /// is **never** performed on this field.
  final String? clientCorrelationId;

  /// Stateless-cursor field: the caller's last seen ledger sequence.
  /// Required (non-null) for bindings that advertise `strictCursor`.
  final int? lastSeenSeq;

  const WireRequest({
    required this.cellId,
    required this.function,
    this.positional,
    this.named,
    required this.correlationId,
    this.clientCorrelationId,
    this.lastSeenSeq,
  });

  @override
  String get kind => 'request';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'cellId': cellId,
        'function': function,
        if (positional != null) 'positional': positional,
        if (named != null) 'named': named,
        'correlationId': correlationId,
        if (clientCorrelationId != null)
          'clientCorrelationId': clientCorrelationId,
        if (lastSeenSeq != null) 'lastSeenSeq': lastSeenSeq,
      };

  /// Decodes a [WireRequest] encoded by [toJson].
  factory WireRequest.fromJson(Map<String, Object?> json) => WireRequest(
        cellId: json['cellId'] as String,
        function: json['function'] as String,
        positional: (json['positional'] as Map?)?.cast<String, Object?>(),
        named: (json['named'] as Map?)?.cast<String, Object?>(),
        correlationId: json['correlationId'] as String,
        clientCorrelationId: json['clientCorrelationId'] as String?,
        lastSeenSeq: json['lastSeenSeq'] as int?,
      );
}

/// An outbound result: the target's real [ApplyOutcome], or — when the
/// ledger entry has not landed yet — a pending marker with the last
/// known receipt JSON.
///
/// ### When to use
/// * The router's reply to a [WireRequest]: accepted, rejected, or
///   staged — never an exposure or cursor failure (those are
///   [WireError]).
///
/// ### How it works
/// The router packages the outcome of `binding.target.apply` verbatim;
/// a decoded response carries the wire form under [outcomeJson] because
/// a live [ApplyOutcome] cannot be reconstructed without the live cell.
///
/// ### Non-obvious
/// A response with [pendingReceipt] `true` is an **accepted pulse whose
/// ledger entry has not landed** — the definitive receipt arrives via
/// the ledger stream (`skin.ledger.entry`), not by guessing.
///
/// ### See also
/// [WireOutcome], [WireReceipt], [SkinMembrane.request].
/// {@category Wire Messages}
final class WireResponse extends WireMessage {
  /// The correlation id echoed from the originating [WireRequest].
  final String correlationId;

  /// The client-chosen correlation id, echoed verbatim when the
  /// request carried one.
  final String? clientCorrelationId;

  /// The target's own outcome. `null` only when [pendingReceipt] is
  /// `true` (live) or when the response was decoded from JSON (a live
  /// [ApplyOutcome] cannot be reconstructed without the live target
  /// cell — [outcomeJson] carries the wire form instead).
  final ApplyOutcome<Object?>? outcome;

  /// The wire outcome JSON for a decoded response; `null` for live
  /// responses and for pending ones.
  final WireOutcome? outcomeJson;

  /// When `true`, [outcome] is `null` and [receiptJson] carries the last
  /// known receipt (or is absent). The definitive receipt arrives via
  /// the ledger stream (`skin.ledger.entry`).
  final bool pendingReceipt;

  /// Best-effort last-known receipt JSON while [pendingReceipt] is
  /// `true`; `null` when no receipt has been seen for this cell at all.
  final Map<String, Object?>? receiptJson;

  /// Invariant: a response is either pending, carries a live outcome,
  /// or carries a decoded outcome JSON.
  const WireResponse({
    required this.correlationId,
    this.clientCorrelationId,
    this.outcome,
    this.outcomeJson,
    this.pendingReceipt = false,
    this.receiptJson,
  }) : assert(
          pendingReceipt || outcome != null || outcomeJson != null,
          'WireResponse: outcome == null requires pendingReceipt or '
          'a decoded outcomeJson',
        );

  @override
  String get kind => 'response';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'correlationId': correlationId,
        if (clientCorrelationId != null)
          'clientCorrelationId': clientCorrelationId,
        if (outcome != null) 'outcome': wireOutcomeJson(outcome!),
        if (outcomeJson != null) 'outcome': outcomeJson!.toJson(),
        'pendingReceipt': pendingReceipt,
        if (receiptJson != null) 'receipt': receiptJson,
      };

  /// Decodes a [WireResponse] encoded by [toJson].
  ///
  /// A decoded response carries the JSON outcome under [outcomeJson] —
  /// a live [ApplyOutcome] cannot be reconstructed without the live
  /// target cell. [outcome] is therefore `null` after decoding.
  factory WireResponse.fromJson(Map<String, Object?> json) => WireResponse(
        correlationId: json['correlationId'] as String,
        clientCorrelationId: json['clientCorrelationId'] as String?,
        outcomeJson: json['outcome'] == null
            ? null
            : WireOutcome.fromJson(
                (json['outcome'] as Map).cast<String, Object?>()),
        pendingReceipt: json['pendingReceipt'] as bool? ?? false,
        receiptJson: (json['receipt'] as Map?)?.cast<String, Object?>(),
      );
}

/// An outbound state observation: a target cell's value changed.
///
/// Egress is **not a reply** — it carries no correlation id and can
/// never complete a pending `request()`.
///
/// ### When to use
/// * Pushing state changes to observers: SSE `/skin/observe/:cellId`,
///   MCP notifications, and `SkinClient.observe`.
///
/// ### How it works
/// With a bound ledger, egress is driven by `Ledger.tail`: the entry's
/// own receipt pairs with the entry's own pulse payload (taken from the
/// entry's canonical stored JSON). Without a ledger, target
/// observations are always [pendingReceipt] — a receipt is never
/// fabricated and never borrowed from an earlier change.
///
/// ### Non-obvious
/// `pendingReceipt` on a ledgered change is always `false`; on an
/// unledgered change it is always `true`. There is no in-between state
/// where a guess is presented as authoritative.
///
/// ### See also
/// [wireStateChangeForEntry], [SkinMembrane.responses],
/// [WireLedgerEntry].
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is an observation, not a command reply.
/// **When to use:** streaming target state changes to observers (SSE, MCP notifications, Dart clients).
/// **When NOT to use:** completing a request — it has no correlation id; replies are [WireResponse] or [WireError].
/// **Live signature:** `const WireStateChange({required String cellId, Object? payload, WireReceipt? receipt, bool pendingReceipt = false})` — pinned at `cell_skin: 0.1.0`
/// **Do NOT confuse with:** `WireResponse.pendingReceipt` (an accepted pulse whose entry is pending), or `WireLedgerEntry` (the audit row itself).
/// **Guide:** `ARCHITECTURE-Skin.md` §4 (receipt provenance).
/// **Example:** `example/lib/widgets/home_pane.dart` (the thermostat readout observes this variant).
/// **Cross-layer:** the payload is the cell's value — its meaning belongs to the domain cell, not the skin.
/// **Minimal compilable example**
/// ```dart
/// final change = WireStateChange(
///   cellId: 'home.living.thermostat',
///   payload: 21,
///   pendingReceipt: true, // no ledger bound — no receipt exists
/// );
/// ```
/// {@category Egress}
final class WireStateChange extends WireMessage {
  /// The registered graph name of the cell that changed.
  final String cellId;

  /// The new state value, when JSON-serialisable (otherwise omitted —
  /// the ledger entry carries the authoritative payload).
  final Object? payload;

  /// The last known receipt for [cellId], when the ledger has recorded
  /// one. It may belong to an *earlier* change while [pendingReceipt]
  /// is `true`; it is never fabricated.
  final WireReceipt? receipt;

  /// Whether the ledger entry for this change has not landed yet.
  final bool pendingReceipt;

  const WireStateChange({
    required this.cellId,
    this.payload,
    this.receipt,
    this.pendingReceipt = true,
  });

  @override
  String get kind => 'stateChange';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'cellId': cellId,
        if (payload != null) 'payload': payload,
        if (receipt != null) 'receipt': receipt!.toJson(),
        'pendingReceipt': pendingReceipt,
      };

  /// Decodes a [WireStateChange] encoded by [toJson].
  factory WireStateChange.fromJson(Map<String, Object?> json) =>
      WireStateChange(
        cellId: json['cellId'] as String,
        payload: json['payload'],
        receipt: json['receipt'] == null
            ? null
            : WireReceipt.fromJson(
                (json['receipt'] as Map).cast<String, Object?>()),
        pendingReceipt: json['pendingReceipt'] as bool? ?? true,
      );
}

/// A fire-and-forget wire event (MCP notification, SSE ping, …).
final class WireNotification extends WireMessage {
  final String method;
  final Map<String, Object?> params;

  const WireNotification({required this.method, this.params = const {}});

  @override
  String get kind => 'notification';

  @override
  Map<String, Object?> toJson() =>
      {'kind': kind, 'method': method, 'params': params};

  /// Decodes a [WireNotification] encoded by [toJson].
  factory WireNotification.fromJson(Map<String, Object?> json) =>
      WireNotification(
        method: json['method'] as String,
        params: (json['params'] as Map?)?.cast<String, Object?>() ?? const {},
      );
}

/// Asks the membrane for its tool catalogue.
final class WireManifestRequest extends WireMessage {
  const WireManifestRequest();

  @override
  String get kind => 'manifestRequest';

  @override
  Map<String, Object?> toJson() => {'kind': kind};
}

/// Carries the [SkinManifest] back to a discovery client.
final class WireManifestResponse extends WireMessage {
  final SkinManifest manifest;

  const WireManifestResponse({required this.manifest});

  @override
  String get kind => 'manifestResponse';

  @override
  Map<String, Object?> toJson() =>
      {'kind': kind, 'manifest': manifest.toJson()};

  /// Decodes a [WireManifestResponse] encoded by [toJson].
  factory WireManifestResponse.fromJson(Map<String, Object?> json) =>
      WireManifestResponse(
        manifest: SkinManifest.fromJson(
            (json['manifest'] as Map).cast<String, Object?>()),
      );
}

/// A ledger entry streamed over the wire (`skin.ledger.entry`).
final class WireLedgerEntry extends WireMessage {
  final LedgerEntry entry;

  const WireLedgerEntry({required this.entry});

  @override
  String get kind => 'ledgerEntry';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'entry': entry.toJson()};

  /// Decodes a [WireLedgerEntry] encoded by [toJson].
  ///
  /// The decoded entry carries its stored receipt JSON; its live
  /// `receipt.cell` cannot be reconstructed without the graph.
  factory WireLedgerEntry.fromJson(Map<String, Object?> json) =>
      WireLedgerEntry(
        entry: LedgerEntry.fromJson(
            (json['entry'] as Map).cast<String, Object?>()),
      );
}

/// An error that has no receipt: exposure-gate misses, transport
/// failures, and cursor conflicts.
///
/// This variant exists because a [WireResponse] always carries the
/// target's real `ApplyOutcome` — an error produced *before* the target's
/// `apply` ran has no receipt, and must not pretend otherwise.
///
/// ### When to use
/// * Exposure rejections (`unknown_tool`, `bad_arguments`,
///   `cursor_required`, `conflict`) and transport failures
///   (`transport_error`) — never domain denials (those are
///   `ApplyRejected` inside a [WireResponse]).
///
/// ### How it works
/// The router and adapters produce it before `target.apply` runs; the
/// stable [code] maps to an HTTP status (404/409/422/428/500/504) and
/// the [message] never echoes raw internal exception text.
///
/// ### Non-obvious
/// Domain denials *do* produce receipts and are responses; an error
/// without a receipt must not masquerade as one — that is the entire
/// reason this variant exists.
///
/// ### See also
/// [WireResponse], [SkinRouter].
/// {@category Wire Messages}
final class WireError extends WireMessage {
  final String correlationId;

  /// The client-chosen correlation id, echoed verbatim when the
  /// request carried one.
  final String? clientCorrelationId;

  final String code;
  final String message;

  const WireError({
    required this.correlationId,
    this.clientCorrelationId,
    required this.code,
    required this.message,
  });

  @override
  String get kind => 'error';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'correlationId': correlationId,
        if (clientCorrelationId != null)
          'clientCorrelationId': clientCorrelationId,
        'code': code,
        'message': message,
      };

  /// Decodes a [WireError] encoded by [toJson].
  factory WireError.fromJson(Map<String, Object?> json) => WireError(
        correlationId: json['correlationId'] as String,
        clientCorrelationId: json['clientCorrelationId'] as String?,
        code: json['code'] as String,
        message: json['message'] as String,
      );
}
