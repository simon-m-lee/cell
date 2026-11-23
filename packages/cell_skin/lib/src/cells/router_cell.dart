// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The skin router cell.
///
/// Role: route inbound wire pulses to the right target cell, invoke
/// **`target.apply`** — never the router's own apply — and package the
/// target's real receipt back into a response pulse. That is the
/// receipt-provenance rule: `receipt.cell`, `receipt.function` and
/// `receipt.ledgerSeq` stay accurate to the domain, not the transport.
///
/// The router is materialised as `Cell.asyncMap` (the plan's primary
/// shape). The synchronous `Cell.hub` variant is an optimisation for
/// all-sync binding sets and is deliberately not duplicated here: one
/// dispatch path means one receipt-provenance test covers the wire.
///
/// Before the target's apply runs, the router enforces the exposure
/// gate, the stateless cursor (when the binding is strict), the
/// declared argument schema (when one exists), and idempotency: a
/// request whose server-assigned correlation id was already dispatched
/// is answered with the stored outcome instead of re-applying.
/// {@category Architecture}
library;

import 'package:cell/cell.dart';

import '../binding/skin_binding.dart';
import '../binding/skin_whitelist.dart';
import '../manifest/skin_manifest.dart';
import '../wire/wire_message.dart';
import '../wire/wire_schema.dart';

/// The dispatch brain behind the router cell. Testable without a live
/// cell, then materialised with [SkinRouter.cell].
final class SkinRouter {
  /// The registered graph the router serves.
  final CellGraph graph;

  /// The binding table (the exposure registry).
  final SkinBindingTable bindings;

  /// The optional declarative exposure policy.
  final SkinWhitelist? whitelist;

  /// The graph's ledger, when one is bound (cursor checks).
  final Ledger? ledger;

  /// The receipt join for egress pulses.

  /// Human-readable cell descriptions for the manifest.
  final Map<String, String>? descriptions;

  /// Optional observer for every dispatched outcome (tests, adapters).
  final void Function(WireRequest request, ApplyOutcome<Object?> outcome)?
      onApplied;

  /// Idempotency store: correlation key → (outcome, response type).
  /// The stored outcome is re-wrapped with the *current* request's
  /// correlation ids on replay — a cached response that kept its first
  /// request's id would never match the retry's waiter.
  static const int _maxIdempotent = 256;
  final Map<String, (ApplyOutcome<Object?>, String)> _idempotent = {};

  SkinRouter({
    required this.graph,
    required this.bindings,
    this.whitelist,
    this.ledger,
    this.descriptions,
    this.onApplied,
  });

  /// Routes one inbound wire pulse. Returns `null` to suppress.
  Future<Pulse<WireMessage>?> route(
    Pulse<WireMessage> pulse, {
    required EffectJournal journal,
  }) async {
    final payload = pulse.payload;
    if (payload is WireRequest) {
      return _dispatch(pulse, payload);
    }
    if (payload is WireManifestRequest) {
      return _manifest(pulse);
    }
    // Notifications and unknown pulse types pass through silently.
    return null;
  }

  Future<Pulse<WireMessage>> _dispatch(
    Pulse<WireMessage> pulse,
    WireRequest request,
  ) async {
    // ── Idempotency: a duplicate correlation key never re-applies ────
    // The key prefers the client-chosen id: a client that retries the
    // same logical call (after a timeout, say) gets the stored outcome
    // instead of a double-apply.
    final idempotencyKey = request.clientCorrelationId ?? request.correlationId;
    final cached = _idempotent[idempotencyKey];
    if (cached != null) {
      final response = WireResponse(
        correlationId: request.correlationId,
        clientCorrelationId: request.clientCorrelationId,
        outcome: cached.$1,
      );
      return Pulse<WireMessage>.governed(
        payload: response,
        type: cached.$2,
        source: pulse.source,
        context: pulse.context,
      );
    }

    // ── Exposure gate ────────────────────────────────────────────────
    // A function not in the table (or not whitelisted) simply does not
    // exist on the wire. No receipt is produced.
    final binding = bindings.lookup(request.cellId, request.function);
    if (binding == null ||
        (whitelist != null &&
            !whitelist!.allows(request.cellId, request.function))) {
      return _error(
        pulse,
        request,
        'unknown_tool',
        'no binding for "${request.cellId}.${request.function}"',
      );
    }

    // ── Argument envelope + declared schema ─────────────────────────
    // Reject malformed wire arguments and schema violations before the
    // target's apply ever runs.
    final ApplyCommand command;
    try {
      command = binding.toApplyCommand(request);
    } on BadArgumentsException catch (error) {
      return _error(pulse, request, 'bad_arguments', error.message);
    }
    final schemaError = _validateAgainstSchema(binding, command);
    if (schemaError != null) {
      return _error(pulse, request, 'bad_arguments', schemaError);
    }

    // ── Stateless-cursor check (opt-in per binding) ──────────────────
    if (binding.strictCursor) {
      final cursor = request.lastSeenSeq;
      if (cursor == null) {
        return _error(
          pulse,
          request,
          'cursor_required',
          'strictCursor binding "${request.function}" requires '
              'lastSeenSeq',
        );
      }
      final ledger = this.ledger;
      if (ledger == null) {
        return _error(
          pulse,
          request,
          'conflict',
          'strictCursor binding requires a bound ledger',
        );
      }
      final head = await ledger.lastSeq;
      // Strict semantics: the cursor is the *global* ledger head and
      // must match it exactly. A cursor behind the head means the
      // caller acted on stale state; a cursor ahead means it cannot
      // have seen the current state. Both conflict.
      if (cursor != head) {
        return _error(
          pulse,
          request,
          'conflict',
          cursor < head
              ? 'conflict: ledger advanced to $head'
              : 'conflict: cursor $cursor is ahead of ledger head $head',
        );
      }
    }

    // ── The plug: the target's own apply runs the domain gate ───────
    final ApplyOutcome<Object?> outcome;
    try {
      outcome = await binding.target.apply<Object?>(command);
    } catch (error) {
      return _error(
        pulse,
        request,
        'transport_error',
        'dispatch failed: ${error.runtimeType}',
      );
    }

    onApplied?.call(request, outcome);

    final requestType = pulse.type;
    final responseType = requestType == SkinPulseTypes.restApplyRequest
        ? SkinPulseTypes.restResponseType(outcome)
        : SkinPulseTypes.resultType(outcome);
    final response = WireResponse(
      correlationId: request.correlationId,
      clientCorrelationId: request.clientCorrelationId,
      outcome: outcome,
    );
    _remember(idempotencyKey, (outcome, responseType));
    return Pulse<WireResponse>.governed(
      payload: response,
      type: responseType,
      source: binding.target,
      context: pulse.context,
    );
  }

  void _remember(String correlationId, (ApplyOutcome<Object?>, String) entry) {
    if (_idempotent.length >= _maxIdempotent) {
      _idempotent.remove(_idempotent.keys.first);
    }
    _idempotent[correlationId] = entry;
  }

  /// Validates the declared [JsonSchema] (when present) against the
  /// wire arguments. Returns an error message, or `null` when the
  /// arguments are acceptable.
  static String? _validateAgainstSchema(
    SkinBinding binding,
    ApplyCommand command,
  ) {
    final schema = binding.argumentSchema;
    if (schema == null || schema.type != 'object') return null;
    final properties = schema.properties;
    if (properties == null) return null;
    final positional = command.arguments.positionalArguments;
    if (positional != null) {
      final propertySchemas = properties.values.toList();
      for (var i = 0; i < positional.length; i++) {
        if (i >= propertySchemas.length) break;
        final error = _checkValue(propertySchemas[i], positional[i]);
        if (error != null) return 'argument $i: $error';
      }
    }
    final named = command.arguments.namedArguments;
    if (named != null) {
      for (final entry in named.entries) {
        final name = _symbolName(entry.key);
        final property = properties[name];
        if (property == null) continue;
        final error = _checkValue(property, entry.value);
        if (error != null) return 'argument "$name": $error';
      }
    }
    return null;
  }

  static String? _checkValue(JsonSchema schema, Object? value) {
    if (value == null) return null; // null is always representable
    final type = schema.type;
    if (type != null) {
      final ok = switch (type) {
        'integer' => value is int,
        'number' => value is num,
        'string' => value is String,
        'boolean' => value is bool,
        'array' => value is List,
        'object' => value is Map,
        _ => true,
      };
      if (!ok) return 'expected $type, got ${value.runtimeType}';
    }
    if (value is num) {
      if (schema.minimum != null && value < schema.minimum!) {
        return 'below minimum ${schema.minimum}';
      }
      if (schema.maximum != null && value > schema.maximum!) {
        return 'above maximum ${schema.maximum}';
      }
    }
    return null;
  }

  static String _symbolName(Symbol symbol) {
    final text = symbol.toString();
    if (text.startsWith('Symbol("') && text.endsWith('")')) {
      return text.substring(8, text.length - 2);
    }
    return text;
  }

  Future<Pulse<WireMessage>> _manifest(Pulse<WireMessage> pulse) async {
    final manifest = SkinManifest.describe(
      graph: graph,
      bindings: bindings,
      whitelist: whitelist,
      descriptions: descriptions,
    );
    return Pulse<WireManifestResponse>.governed(
      payload: WireManifestResponse(manifest: manifest),
      type: SkinPulseTypes.manifestResponse,
      context: pulse.context,
    );
  }

  Pulse<WireMessage> _error(
    Pulse<WireMessage> pulse,
    WireRequest request,
    String code,
    String message,
  ) =>
      Pulse<WireError>.governed(
        payload: WireError(
          correlationId: request.correlationId,
          clientCorrelationId: request.clientCorrelationId,
          code: code,
          message: message,
        ),
        type: SkinPulseTypes.errorTransport,
        context: pulse.context,
      );

  /// Materialises the router as a framework [Cell.asyncMap].
  ///
  /// `concurrency: 1` is deliberate: under an active `LedgerScope` the
  /// framework requires serial execution so every effect is
  /// attributable to exactly one ledger entry (`latestOnly` must stay
  /// `false` for the same reason). Serial dispatch is also the honest
  /// wire semantics — responses leave in apply order.
  Cell cell(Cell inbound, {required EffectJournal journal}) =>
      Cell.asyncMap<Pulse<WireMessage>, Pulse<WireMessage>?>(
        inbound,
        (wirePulse, {required EffectJournal journal}) =>
            route(wirePulse, journal: journal),
        journal: journal,
        concurrency: 1,
      );
}
