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

import 'dart:async';

import 'package:cell/cell.dart';

import '../binding/skin_binding.dart';
import '../binding/skin_whitelist.dart';
import '../manifest/skin_manifest.dart';
import '../security/skin_auth.dart';
import '../security/skin_call.dart';
import '../security/skin_policy.dart';
import '../wire/idempotency_store.dart';
import '../wire/wire_message.dart';
import '../wire/wire_outcome.dart';
import '../wire/wire_receipt.dart';

/// The dispatch brain responsible for governing the journey of signals from the membrane to the somatic graph.
///
/// In the framework's biological metaphor, [SkinRouter] acts as the **Synaptic Junction**.
/// It intercepts every **Nervous Signal** ([WireMessage]) arriving at the **Skin Membrane**
/// and orchestrates its **Command Journey** toward a specific target cell.
///
/// ### Receipt Provenance
/// A core responsibility of the router is maintaining **Forensic Integrity**. It invokes
/// `target.apply` rather than its own, ensuring that the resulting **Forensic Receipt**
/// correctly attributes the **Somatic State Transition** to the domain cell and
/// its specific "DNA" (receptor logic), rather than the transport adapter.
///
/// ### Integrity Gates
/// Before a signal is allowed to mutate the graph, the router enforces several
/// sequential gates:
/// 1.  **Exposure Gate**: Checks the [SkinBindingTable] to ensure the pore is open.
/// 2.  **Idempotency Gate**: Uses **Impulse Memory** to prevent duplicate transitions
///     from the same **Causal Link**.
/// 3.  **Schema Gate**: Validates the **Skin Payload** against the **Somatic Blueprint**.
/// 4.  **Cursor Gate**: Enforces **Causal Linkage** by verifying the signal's
///     `lastSeenSeq` against the **Forensic Ledger**.
///
/// ### Materialization
/// The router is typically materialized as a `Cell.asyncMap`. It enforces a
/// **Concurrency Limit of 1** to ensure that all transitions are anchored in
/// the ledger in a deterministic, serial order, preserving the system's chronological
/// "Source of Truth."
///
/// ### Ledger scope
/// With a bound [ledger], every target apply runs inside the graph's
/// `LedgerScope`: the router opens `graph.run` around the apply only when
/// no scope is already active, and reuses an existing scope on the same
/// ledger (see the four-row rule on the private `_runTarget`). A membrane
/// opened without a ledger still does not record.
///
/// ### See also
/// - [SkinMembrane]: The physical boundary layer containing this router.
/// - [WireRequest]: The primary nervous signal handled by the router.
/// - [SkinBinding]: The definition of the pore the signal targets.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the central logic for signal routing.
/// **Live signature:** `final class SkinRouter { int get queued; int get inFlight; bool closing; void Function()? onRouted; }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Governance:** This class is the final arbiter before a pulse reaches a domain cell.
/// **Traceability:** Failures here result in **Membrane Rejections** ([WireError]);
/// successes result in **Forensic Receipts**.
final class SkinRouter {
  /// The reactive organ representing the entire somatic body.
  final CellGraph graph;

  /// The authoritative registry of physically exposed pores.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Registry**.
  final SkinBindingTable bindings;

  /// The optional declarative filter for the membrane.
  ///
  /// Acts as a **Membrane Filter** that can further restrict access to
  /// specific pores regardless of their registration in the table.
  final SkinWhitelist? whitelist;

  /// The system's permanent history, used for cursor-based integrity checks.
  ///
  /// In the framework's biological metaphor, this is the **Forensic Ledger**.
  final Ledger? ledger;

  /// The technical map used to provide human-readable context in the manifest.
  final Map<String, String>? descriptions;

  /// An optional hook triggered every time a **Command Journey** completes.
  ///
  /// Used primarily for **Forensic Monitoring** and transport-layer adaptations.
  final void Function(WireRequest request, ApplyOutcome<Object?> outcome)?
  onApplied;

  /// A cache of recently processed impulses to prevent duplicate transitions.
  ///
  /// In the framework's biological metaphor, this is the **Impulse Memory**.
  /// It stores the **External Echo** (response) for a given **Causal Link**
  /// (correlation ID) to ensure that retries do not trigger a second
  /// **Somatic State Transition**.
  final IdempotencyStore idempotency;

  /// The time source for stored idempotency records.
  final DateTime Function() clock;

  /// The application's authorization hook. `null` means allow, and the
  /// function is not invoked. Called after exposure and before schema,
  /// cursor, and `apply`.
  final SkinAuthorizer? authorizer;

  int _queued = 0;
  int _inFlight = 0;

  /// Set by `SkinMembrane.close`: a request whose dispatch starts after
  /// this is answered `closed` and never applies. An apply already in
  /// flight is not cancelled — the caller's timeout is its only bound,
  /// and a hung apply keeps holding the serial queue.
  bool closing = false;

  /// Called from `route()`'s finally, once per dispatch — including a
  /// dispatch whose waiter already gave up. The membrane decrements its
  /// `maxQueued` slot here.
  void Function()? onRouted;

  /// Whether [principal] may read [cellId] through the read routes
  /// (manifest, observe, ledger). A `null` authorizer reads everything
  /// exposure allows. A non-null one must allow **every** binding of
  /// the cell; a throwing hook denies. Not cached: every read decision
  /// consults the hook.
  Future<bool> mayRead(SkinPrincipal principal, String cellId) async {
    final hook = authorizer;
    if (hook == null) return true;
    final cellBindings =
        bindings.all.where((b) => b.cellId == cellId).toList();
    if (cellBindings.isEmpty) return false;
    for (final binding in cellBindings) {
      try {
        if (!await hook(principal, binding)) return false;
      } catch (_) {
        // Fail closed: a broken hook cannot open a read route.
        return false;
      }
    }
    return true;
  }

  /// Requests the router has received but not yet finished (queued plus
  /// the one in flight).
  int get queueDepth => _queued;

  /// Dispatches currently inside the router (0 or 1 under
  /// `concurrency: 1`).
  int get inFlight => _inFlight;

  /// Receipt id → binding wire name, filled as soon as an apply returns
  /// (before the queued append drains, so the membrane's ledger listener
  /// can label the entry at emission time). Capped at 256 so a long-lived
  /// membrane cannot grow this map forever. A miss keeps the ledger's
  /// stored function text — synthetic `_emit` rows and inner `txApply`
  /// rows carry different receipt ids and never hit this map.
  static const int _maxReceiptLabels = 256;
  final Map<String, String> _receiptLabels = {};

  /// Whether a ledgered apply must have written exactly the receipt it
  /// returned (the strict rule for `state`/`raw` bindings). Ignored when
  /// no ledger is bound.
  final bool strictReceipts;

  SkinRouter({
    required this.graph,
    required this.bindings,
    this.whitelist,
    this.ledger,
    this.descriptions,
    this.onApplied,
    this.strictReceipts = true,
    required this.idempotency,
    this.clock = DateTime.now,
    this.authorizer,
  });

  /// The binding's wire-facing name for a written row's receipt id, when
  /// this router applied that row. `null` on a miss (replayed history or
  /// an inner `txApply` closure) — the stored text is then kept.
  String? functionLabelFor(String receiptId) => _receiptLabels[receiptId];

  /// Processes a single **Nervous Signal** arriving from the environment.
  ///
  /// This method acts as the **Signal Dispatcher**. It identifies the type
  /// of impulse—be it a **Discovery Impulse** ([WireManifestRequest]) or a
  /// **Command Journey** ([WireRequest])—and initiates the appropriate
  /// somatic response.
  ///
  /// Returns a `Pulse<WireMessage>` representing the **External Echo**,
  /// or `null` if the signal is a volatile notification that requires
  /// no somatic feedback.
  Future<Pulse<WireMessage>?> route(
    Pulse<WireMessage> pulse, {
    required EffectJournal journal,
  }) async {
    _queued++;
    try {
      final payload = pulse.payload;
      if (payload is WireRequest) {
        return await _dispatch(pulse, payload);
      }
      if (payload is WireManifestRequest) {
        return await _manifest(pulse);
      }
      // Notifications and unknown pulse types pass through silently.
      return null;
    } finally {
      _queued--;
      onRouted?.call();
    }
  }

  Future<Pulse<WireMessage>> _dispatch(
    Pulse<WireMessage> pulse,
    WireRequest request,
  ) async {
    _inFlight++;
    try {
      return await _dispatchInner(pulse, request);
    } finally {
      _inFlight--;
    }
  }

  Future<Pulse<WireMessage>> _dispatchInner(
    Pulse<WireMessage> pulse,
    WireRequest request,
  ) async {
    // The closing gate comes before the claim: a request that was
    // emitted (or queued) before `SkinMembrane.close` must not start
    // after it, and it must not claim an idempotency key.
    if (closing) {
      return _error(pulse, request, 'closed', 'the membrane was closed');
    }

    // ── Idempotency claim ───────────────────────────────────────────
    // The key prefers the client-chosen id: a client that retries the
    // same logical call (after a timeout, say) gets the stored outcome
    // instead of a double-apply. The key is scoped by the request's
    // actor, and the body hash covers the exact request.
    final id = request.clientCorrelationId ?? request.correlationId;
    final actor = pulse.context.actor;
    final storeKey = idempotencyStoreKey(
      actor: (actor == null || actor.isEmpty) ? null : actor,
      id: id,
    );
    final String bodyHash;
    try {
      bodyHash = idempotencyFingerprint(request);
    } catch (_) {
      return _error(pulse, request, 'bad_arguments', 'arguments are not JSON');
    }

    final claimed = await _claim(pulse, request, storeKey, bodyHash);
    if (claimed != null) return claimed;

    Future<Pulse<WireMessage>> fail(String code, String message) async {
      await idempotency.abort(storeKey);
      return _error(pulse, request, code, message);
    }

    // ── Queue deadline ──────────────────────────────────────────────
    // One check, before apply — `isBefore` means an equal timestamp
    // times out. A request that is still queued when its deadline
    // passes is refused here and never calls apply; the abort frees the
    // idempotency key so a later attempt is a new apply. An idempotency
    // hit above never consults the deadline, and an apply that already
    // started is never cancelled.
    final deadline = request.deadline;
    if (deadline != null && !clock().isBefore(deadline)) {
      return fail(
        'queue_timeout',
        'the request was still queued when its deadline passed and was not applied',
      );
    }

    // ── Exposure gate ────────────────────────────────────────────────
    // A function not in the table (or not whitelisted) simply does not
    // exist on the wire. No receipt is produced.
    final binding = bindings.lookup(request.cellId, request.function);
    if (binding == null ||
        (whitelist != null &&
            !whitelist!.allows(request.cellId, request.function))) {
      return fail(
        'unknown_tool',
        'no binding for "${request.cellId}.${request.function}"',
      );
    }

    // ── Authorization hook ──────────────────────────────────────────
    // Only after the binding was found and the whitelist allows it, and
    // before schema, cursor, and apply. A hidden tool is unknown_tool
    // above and never reaches the hook. `false` aborts the idempotency
    // claim — a denial is not cached, so a later allowed principal is a
    // new apply. The hook runs on this serial mapper: a slow hook holds
    // the queue.
    // No snapshot does not mean allow: the hook still runs and can
    // refuse `anonymous`.
    final parsed = principalFrom(pulse.context);
    final principal = parsed ?? SkinPrincipal.anonymous();
    if (authorizer != null) {
      final bool allowed;
      try {
        allowed = await authorizer!(principal, binding);
      } catch (error) {
        // Same transport_error path as a throwing apply: the runtime
        // type only, never the message.
        return fail('transport_error', 'dispatch failed: ${error.runtimeType}');
      }
      if (!allowed) {
        return fail('forbidden', 'not authorized');
      }
    }

    // ── Argument envelope + declared schema ─────────────────────────
    // Reject malformed wire arguments and schema violations before the
    // target's apply ever runs. The validator reads the wire request,
    // not the ApplyCommand; an explicit schema is enforced, an observed
    // schema never is.
    final ApplyCommand command;
    try {
      command = binding.toApplyCommand(request);
    } on BadArgumentsException catch (error) {
      return fail('bad_arguments', error.message);
    }
    final schemaError = validateBindingArguments(binding, request);
    if (schemaError != null) {
      return fail('bad_arguments', schemaError);
    }

    // ── Stateless-cursor check (opt-in per binding) ──────────────────
    if (binding.strictCursor) {
      final cursor = request.lastSeenSeq;
      if (cursor == null) {
        return fail(
          'cursor_required',
          'strictCursor binding "${request.function}" requires '
              'lastSeenSeq',
        );
      }
      final ledger = this.ledger;
      if (ledger == null) {
        return fail(
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
        return fail(
          'conflict',
          cursor < head
              ? 'conflict: ledger advanced to $head'
              : 'conflict: cursor $cursor is ahead of ledger head $head',
        );
      }
    }

    // ── The plug: the target's own apply runs the domain gate ───────
    // The domain gate and the binding body see the caller through the
    // SkinCall zone installed around the apply — built from the request
    // pulse, never from anything the body could forge.
    final call = SkinCall(
      principal: parsed,
      pulseContext: pulse.context,
      deadline: request.deadline,
    );

    // Re-read the head immediately before apply (the strict-cursor check
    // above read the same store, and nothing may start in between under
    // `concurrency: 1`, but a `graph.run` outside the membrane can still
    // advance the head during this await — a documented residual race).
    final int before;
    final ApplyOutcome<Object?> outcome;
    try {
      before = ledger == null ? -1 : await ledger!.lastSeq;
      outcome = await _runTarget(binding, command, call);
    } on NoSuchMethodError {
      // A wrong positional/named arity dies inside `Function.apply`
      // itself. A function body that throws the same error is
      // mislabeled — a documented residual, not a reason to use
      // dart:mirrors.
      await idempotency.abort(storeKey);
      return _error(
        pulse,
        request,
        'bad_arguments',
        'arguments do not match the function',
      );
    } catch (error) {
      await idempotency.abort(storeKey);
      return _error(
        pulse,
        request,
        'transport_error',
        'dispatch failed: ${error.runtimeType}',
      );
    }

    onApplied?.call(request, outcome);

    // The rows this apply wrote (the half-open range after the previous
    // head). `entriesSince` is inclusive and `index == seq`, so the
    // first new row is `before + 1`.
    final written = ledger == null
        ? const <LedgerEntry>[]
        : await ledger!.entriesSince(before + 1).toList();

    // Strict receipts: a successful ledgered apply must have written
    // exactly the receipt it returned (state/raw rules), or the binding
    // is broken. Rejections append nothing and are exempt. A violation
    // is **post-commit** — the row is already in the ledger — so the
    // claim is completed with a failure record instead of aborted: a
    // retry echoes the same transport_error and never applies again.
    if (strictReceipts && ledger != null && outcome is ApplyAccepted) {
      final violation = binding.strictReceiptViolation(written, outcome);
      if (violation != null) {
        await idempotency.complete(
          storeKey,
          IdempotencyRecord(
            fingerprint: bodyHash,
            responseType: SkinPulseTypes.errorTransport,
            outcomeJson: const {},
            storedAt: clock(),
            failureCode: 'transport_error',
            failureMessage: violation,
          ),
        );
        return _error(pulse, request, 'transport_error', violation);
      }
    }

    // The wire outcome is encoded here, not in the adapter. The stored
    // ledger `function` is `Function.toString()`; the wire label is the
    // binding's name.
    final wireOutcome = WireOutcome.fromJson(wireOutcomeJson(
      outcome,
      functionLabel: binding.functionName,
      requestNamed: request.named,
    ));
    final matching = written
        .where((entry) => entry.receipt.id == outcome.receipt.id)
        .toList();
    if (matching.length == 1) {
      // One row carries the apply receipt: copy that entry's stored
      // receipt onto the wire receipt so ledgerSeq/pulseDigest/versions
      // agree with the row, then restore the wire function label. (The
      // egress label map was already filled before the append drained —
      // see _runTarget.)
      wireOutcome.receipt
        ..addAll(wireReceiptJson(matching.single.receipt))
        ..['function'] = binding.functionName;
    }

    final requestType = pulse.type;
    final responseType = requestType == SkinPulseTypes.restApplyRequest
        ? SkinPulseTypes.restResponseType(outcome)
        : SkinPulseTypes.resultType(outcome);
    final ledgerSeqs = [for (final entry in written) entry.seq];
    final response = WireResponse(
      correlationId: request.correlationId,
      clientCorrelationId: request.clientCorrelationId,
      outcome: outcome,
      outcomeJson: wireOutcome,
      ledgerSeqs: ledgerSeqs.isEmpty ? null : ledgerSeqs,
    );
    // Only accepted/staged attempts are stored; every other exit aborted
    // (or is failing right now). The live outcome stays in the record so
    // `SkinClient.apply` still returns it on a replay.
    switch (outcome) {
      case ApplyAccepted() || ApplyStaged():
        await idempotency.complete(
          storeKey,
          IdempotencyRecord(
            fingerprint: bodyHash,
            responseType: responseType,
            outcomeJson: wireOutcome.toJson(),
            storedAt: clock(),
            liveOutcome: outcome,
          ),
        );
      case ApplyRejected():
        await idempotency.abort(storeKey);
    }
    return Pulse<WireResponse>.governed(
      payload: response,
      type: responseType,
      source: binding.target,
      context: pulse.context,
    );
  }

  /// Resolves the idempotency claim: returns a response pulse to send
  /// instead of the apply (replay or conflict), or `null` when this
  /// dispatch owns the attempt and may proceed.
  Future<Pulse<WireMessage>?> _claim(
    Pulse<WireMessage> pulse,
    WireRequest request,
    String storeKey,
    String bodyHash,
  ) async {
    var attempt = await idempotency.claim(storeKey);
    var abortedWaits = 0;
    while (true) {
      switch (attempt) {
        case IdempotencyOwned():
          return null;
        case IdempotencyReplay(:final record):
          return _replayOrConflict(pulse, request, record, bodyHash);
        case IdempotencyWait(:final settled):
          final record = await settled;
          if (record != null) {
            return _replayOrConflict(pulse, request, record, bodyHash);
          }
          // The owner aborted: claim once more and become the owner.
          abortedWaits++;
          if (abortedWaits >= 2) {
            return _error(
              pulse,
              request,
              'transport_error',
              'idempotency wait aborted',
            );
          }
          attempt = await idempotency.claim(storeKey);
      }
    }
  }

  /// A stored record with the current request's ids: the same fingerprint
  /// replays the stored outcome; a different one is a conflict and never
  /// calls apply.
  Pulse<WireMessage> _replayOrConflict(
    Pulse<WireMessage> pulse,
    WireRequest request,
    IdempotencyRecord record,
    String bodyHash,
  ) {
    if (record.fingerprint != bodyHash) {
      return _error(
        pulse,
        request,
        'idempotency_conflict',
        'clientCorrelationId was already used with a different request',
      );
    }
    final failureCode = record.failureCode;
    if (failureCode != null) {
      // A post-commit failure (a strict-receipt violation) is terminal:
      // the row is in the ledger, so a retry must echo the same error
      // and never apply again.
      return _error(pulse, request, failureCode, record.failureMessage ?? '');
    }
    final response = WireResponse(
      correlationId: request.correlationId,
      clientCorrelationId: request.clientCorrelationId,
      outcome: record.liveOutcome,
      outcomeJson: WireOutcome.fromJson(record.outcomeJson),
    );
    return Pulse<WireMessage>.governed(
      payload: response,
      type: record.responseType,
      source: pulse.source,
      context: pulse.context,
    );
  }

  void _rememberReceiptLabel(String receiptId, String functionName) {
    if (_receiptLabels.length >= _maxReceiptLabels) {
      _receiptLabels.remove(_receiptLabels.keys.first);
    }
    _receiptLabels[receiptId] = functionName;
  }

  /// Runs the target's own apply under the graph's ledger scope.
  ///
  /// The four-row scope rule:
  ///
  /// | `ledger` | `LedgerScope.current` | Action |
  /// |---|---|---|
  /// | null | anything | `target.apply` only. Unledgered membranes stay unledgered. |
  /// | non-null | null | `graph.run(() => target.apply)`. This is REST and a bare `SkinClient.apply`: the HTTP zone has no scope, so the router opens one. |
  /// | non-null | same ledger | `target.apply` only. This is `graph.run(() => client.apply(...))`: the caller already entered the scope. |
  /// | non-null | a different ledger | `StateError`, mapped to `transport_error` by the existing catch. No second append. |
  ///
  /// `graph.run` drains queued appends before it returns, so a row written
  /// here is committed before the response is encoded. Only the target
  /// apply goes inside the scope: exposure, schema, and cursor checks stay
  /// outside, so a rejected request appends nothing.
  ///
  /// The apply receipt's id is remembered for egress labelling as soon as
  /// the apply returns — before the queued append drains — because the
  /// ledger tail emits its entries during that drain and the membrane's
  /// listener resolves the label at emission time. The map is keyed by the
  /// apply receipt's id, so a synthetic `_emit` row or an inner `txApply`
  /// row (different ids) never hits it.
  ///
  /// Residual race, documented not fixed: a `graph.run` outside the
  /// membrane can still advance the head between the cursor read and this
  /// apply. The router queue does not hold a ledger lock across that
  /// await; a `Ledger.exclusive` API in `package:cell` is a follow-up.
  Future<ApplyOutcome<Object?>> _runTarget(
    SkinBinding binding,
    ApplyCommand command,
    SkinCall call,
  ) async {
    // The SkinCall zone is installed around the apply in every branch —
    // inside `graph.run` when the router opens that scope, so the
    // framework's zone fork keeps the LedgerScope while it installs the
    // call.
    FutureOr<ApplyOutcome<Object?>> body() =>
        SkinCall.run(call, () => binding.target.apply<Object?>(command));

    if (ledger == null) {
      return await body();
    }
    final active = LedgerScope.current;
    if (active != null) {
      if (!identical(active.ledger, ledger)) {
        throw StateError(
          'SkinRouter: active LedgerScope is a different ledger than '
          'this membrane',
        );
      }
      final outcome = await body();
      if (outcome is ApplyAccepted) {
        _rememberReceiptLabel(outcome.receipt.id, binding.functionName);
      }
      // The caller's outer `graph.run` owns this scope and drains it on
      // exit; drain it here too so the row this apply queued is in the
      // store before the router pairs the response receipt with it.
      await active.drain();
      return outcome;
    }
    return graph.run(() async {
      final outcome = await body();
      if (outcome is ApplyAccepted) {
        _rememberReceiptLabel(outcome.receipt.id, binding.functionName);
      }
      return outcome;
    });
  }

  Future<Pulse<WireMessage>> _manifest(Pulse<WireMessage> pulse) async {
    final manifest = SkinManifest.describe(
      graph: graph,
      bindings: bindings,
      whitelist: whitelist,
      descriptions: descriptions,
    );
    // A non-null authorizer filters the read catalogue: a cell whose
    // bindings are all denied (or whose hook throws) is omitted. No
    // snapshot still means the hook may refuse `anonymous`.
    final principal = principalFrom(pulse.context) ?? SkinPrincipal.anonymous();
    final readable = <SkinCellDescriptor>[];
    for (final cell in manifest.cells) {
      if (await mayRead(principal, cell.cellId)) readable.add(cell);
    }
    return Pulse<WireManifestResponse>.governed(
      payload: WireManifestResponse(manifest: SkinManifest(cells: readable)),
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
