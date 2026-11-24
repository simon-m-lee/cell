// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The assembled membrane: four Cells, composed from framework
/// primitives, plus the correlation machinery that adapters and clients
/// await on.
///
/// ```text
/// Cell.ingress → Cell.asyncMap → target.apply → Cell.observe → Cell.observe
/// (inbound)      (router)          (the plug)     (egress)        (outbound)
/// ```
///
/// The wire is a `Pulse<WireMessage>` stream; the membrane is four
/// Cells plus their supporting fan-in (`Cell.synthesis` mux, per-target
/// egress observes, and the ledger-tail ingress). Zero non-Cell logic
/// between graph and wire except the binding table — closures that
/// cannot serialise.
/// {@category Architecture}
library;

import 'dart:async';

import 'package:cell/cell.dart';

import '../binding/skin_binding.dart';
import '../binding/skin_whitelist.dart';
import '../client/skin_error.dart';
import '../manifest/skin_manifest.dart';
import '../security/skin_auth.dart';
import '../security/skin_call.dart';
import '../security/skin_policy.dart';
import '../wire/correlation_id.dart';
import '../wire/idempotency_store.dart';
import '../wire/wire_message.dart';
import 'egress_cell.dart';
import 'inbound_cell.dart';
import 'mux_cell.dart';
import 'router_cell.dart';

/// The master orchestrator of the boundary layer, managing the flow between the somatic graph and the environment.
///
/// In the framework's biological metaphor, [SkinMembrane] is the **Somatic Membrane** organ.
/// It acts as the singular, authoritative pipeline that governs how **Nervous Signals**
/// ([WireMessage]) enter the system and how **Forensic Receipts** and state observations
/// are expelled to the outside world.
///
/// ### The Four-Cell Pipeline
/// The membrane is composed of four specialized functional units:
/// 1.  **Inbound ([inbound])**: The entry pore where raw **Skin Payloads** arrive.
/// 2.  **Router ([router])**: The **Synaptic Junction** that performs binding lookups,
///     cursor validation, and triggers the `target.apply` logic.
/// 3.  **Mux ([mux])**: The **Egress Funnel** that aggregates responses, ledger entries,
///     and volatile state changes.
/// 4.  **Outbound ([outbound])**: The terminal pore that writes the finalized
///     **Nervous Signals** to the transport layer.
///
/// ### Forensic Integrity
/// The membrane ensures that every successfully processed command results in an
/// authoritative **Somatic State Transition** recorded in the **Forensic Ledger**.
/// By centralizing all transport (REST, MCP, SSE) through this single pipeline,
/// it prevents "Forensic Ambiguity" and ensures that provenance is always preserved.
///
/// ### Lifecycle and Sealing
/// When a membrane is initialized via [open], it seals the [SkinBindingTable]. This
/// ensures the system's "DNA" (its exposed surface) remains immutable throughout
/// the connection, providing a stable **Somatic Index** for discovery.
///
/// ### See also
/// - [SkinRouter]: The dispatch brain governing the journey.
/// - [SkinBindingTable]: The registry of physically exposed pores.
/// - [WireMessage]: The base envelope for all signals crossing this membrane.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the top-level orchestrator of the boundary.
/// **Live signature:** `final class SkinMembrane { Future<WireMessage> request(WireMessage message, {String type = SkinPulseTypes.restApplyRequest, Duration? timeout, DateTime? deadline, PulseContext? context, SkinPrincipal? principal}); Stream<Pulse<WireMessage>> get responses; int get routerQueueDepth; int get routerInFlight; bool get isClosed; IdempotencyStore? get idempotency; Future<bool> mayRead(SkinPrincipal principal, String cellId); Future<void> close(); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Governance:** All external interaction must pass through this membrane.
/// **Traceability:** Use [responses] to observe the audit trail of the somatic body.
final class SkinMembrane {
  /// The reactive organ representing the entire somatic body.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Graph**.
  /// It contains the cells that the membrane is responsible for "skinning."
  final CellGraph graph;

  /// The authoritative registry of physically exposed pores.
  ///
  /// In the framework's biological metaphor, this is the **Somatic Registry**.
  /// It is sealed at [open] to ensure the membrane's surface remains stable.
  final SkinBindingTable bindings;

  /// The optional declarative filter for the membrane.
  ///
  /// Acts as a **Membrane Filter** to restrict which cells or functions
  /// can physically communicate with the environment.
  final SkinWhitelist? whitelist;

  /// The system's permanent history, if one is bound.
  ///
  /// In the framework's biological metaphor, this is the **Forensic Ledger**.
  /// It allows the membrane to provide authoritative audit streams and
  /// enforce causal consistency via cursor checks.
  final Ledger? ledger;

  /// The entry pore for incoming wire signals.
  ///
  /// In the framework's biological metaphor, this is the **Ingress Pore**.
  /// It receives **Nervous Signals** from transport adapters and injects
  /// them into the pipeline.
  final IngressHandle<Pulse<WireMessage>> inbound;

  /// The cell responsible for dispatching signals to the graph.
  ///
  /// In the framework's biological metaphor, this is the **Synaptic Junction**.
  /// It executes the **Command Journey** by mapping wire requests to
  /// specific cell applications.
  final Cell router;

  /// The dispatch brain behind the [router] cell.
  final SkinRouter dispatcher;

  /// The collection of observation points for exposed cells.
  ///
  /// In the framework's biological metaphor, these are the **Egress Pores**.
  /// Each pore monitors a specific cell for state transitions to be
  /// broadcast to the environment.
  final Map<String, EgressHandle<Pulse>> egress;

  /// The convergence point for all outbound signals.
  ///
  /// In the framework's biological metaphor, this is the **Egress Funnel**.
  /// It collects results from the router and the ledger tail into a
  /// single stream.
  final Cell mux;

  /// The terminal cell writing to the transport layer.
  ///
  /// In the framework's biological metaphor, this is the **Terminal Egress Pore**.
  /// It expels the finalized **Nervous Signals** from the somatic body.
  final EgressHandle<Pulse<WireMessage>> outbound;

  /// The unified stream of every signal that survives the egress funnel.
  ///
  /// Provides an observational view of all **Forensic Ledger Rows**,
  /// **External Echoes** (responses), and **Transient Impulses**
  /// (notifications) leaving the system.
  final Stream<Pulse<WireMessage>> responses;

  final StreamController<Pulse<WireMessage>> _events;
  StreamSubscription<LedgerEntry>? _ledgerSubscription;
  final Set<Completer<WireMessage>> _pendingRequests = {};
  bool _closed = false;

  final Duration _maxQueueWait;
  final DateTime Function() _clock;
  final int? _maxQueued;

  /// Accepted `request()` calls whose router dispatch has not finished:
  /// the one inside `apply` occupies a slot. Incremented synchronously
  /// before the emit, decremented from `route()`'s finally.
  int _outstanding = 0;

  SkinMembrane._({
    required this.graph,
    required this.bindings,
    required this.whitelist,
    required this.ledger,
    required this.inbound,
    required this.router,
    required this.dispatcher,
    required this.egress,
    required this.mux,
    required this.outbound,
    required this.responses,
    required StreamController<Pulse<WireMessage>> events,
    StreamSubscription<LedgerEntry>? ledgerSubscription,
    required Duration maxQueueWait,
    required DateTime Function() clock,
    required int? maxQueued,
  })  : _events = events,
        _ledgerSubscription = ledgerSubscription,
        _maxQueueWait = maxQueueWait,
        _clock = clock,
        _maxQueued = maxQueued;

  /// Assembles the four cells over [graph].
  ///
  /// ### When to use
  /// * Opening the one membrane every transport shares — REST, MCP, and
  ///   Dart clients all sit behind this pipeline.
  ///
  /// ### How it works
  /// The inbound ingress, the `concurrency: 1` router, the egress
  /// observations (or the ledger-tail egress), the synthesis mux, and
  /// the outbound observer are composed here; the binding table is then
  /// sealed and the graph/ledger remain owned by the caller.
  ///
  /// * [bindings] — the exposure registry (required); sealed here, so
  ///   later registrations throw.
  /// * [whitelist] — the optional declarative exposure policy; egress
  ///   cells are only built for cells with at least one whitelisted
  ///   function.
  /// * [ledger] — the graph's bound ledger; enables cursor checks,
  ///   receipt joins and the `skin.ledger.entry` stream.
  /// * [journal] — the effect journal for the framework's effectful
  ///   operators (`Cell.asyncMap`, `Cell.fromStream`).
  /// * [send] — the transport's outbound writer; also feeds
  ///   [responses].
  /// * [inboundContext] — provenance for inbound pulses. The default
  ///   is **least privilege** (`skin:untrusted`); [Context.system] is
  ///   an explicit opt-in.
  /// * [descriptions] — human-readable cell descriptions for the
  ///   manifest.
  /// * [onPolicyWarning] — receives startup validation warnings (e.g.
  ///   whitelist entries that mention no registered binding — a
  ///   likely typo).
  ///
  /// ### Non-obvious
  /// The binding table is sealed before this returns; the manifest and
  /// egress set are frozen for the membrane's whole life. The caller
  /// keeps owning the graph and ledger — [SkinMembrane.close] never
  /// closes them.
  ///
  /// ### AI Agent Guide
  /// **Layer:** Skin — this assembles the membrane; it does not build graph nodes.
  /// **When to use:** a requirement says "expose the graph over REST/MCP", "let remote callers apply commands", or "stream ledger entries to clients".
  /// **When NOT to use:** pure graph work (use `package:cell`), decisions (use `cell_flow`), books (use `cell_tissue`).
  /// **Live signature:** `static Future<SkinMembrane> open({required CellGraph graph, required SkinBindingTable bindings, SkinWhitelist? whitelist, Ledger? ledger, required EffectJournal journal, required void Function(Pulse<WireMessage>) send, Context inboundContext, Map<String, String>? descriptions, void Function(String)? onPolicyWarning, bool strictReceipts = true, IdempotencyStore? idempotency, DateTime Function() clock = DateTime.now, Duration maxQueueWait = Duration(seconds: 30), SkinAuthorizer? authorizer, int? maxQueued})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
  /// **Do NOT confuse with:** `SkinBindingTable.register` (declares exposure) or `RestAdapter.bind` (opens a socket on top of the membrane).
  /// **Guide:** `ARCHITECTURE-Skin.md` §2 (the four cells).
  /// **Example:** `example/lib/mock/mock_home.dart` (builds the Echo Home membrane).
  /// **Cross-layer:** every binding's target must be the graph's registered cell — the domain's `TestCell` gates stay the second gate.
  /// **Minimal compilable example**
  /// ```dart
  /// final thermostat = Cell.state<int>(initial: 20);
  /// final graph = (CellGraph.builder(graphId: 'home')
  ///       ..register('thermostat', thermostat.cell))
  ///     .build();
  /// final bindings = SkinBindingTable()
  ///   ..register(SkinBinding.state(
  ///     cellId: 'thermostat',
  ///     functionName: 'setTarget',
  ///     target: thermostat.cell,
  ///     nextValue: (int target) => target,
  ///   ));
  /// final membrane = await SkinMembrane.open(
  ///   graph: graph,
  ///   bindings: bindings,
  ///   journal: RecordingJournal(),
  ///   send: (_) {},
  /// );
  /// ```
  static Future<SkinMembrane> open({
    required CellGraph graph,
    required SkinBindingTable bindings,
    SkinWhitelist? whitelist,
    Ledger? ledger,
    required EffectJournal journal,
    required void Function(Pulse<WireMessage> pulse) send,
    Context inboundContext = _defaultInboundContext,
    Map<String, String>? descriptions,
    void Function(String message)? onPolicyWarning,
    bool strictReceipts = true,
    IdempotencyStore? idempotency,
    DateTime Function() clock = DateTime.now,
    Duration maxQueueWait = const Duration(seconds: 30),
    SkinAuthorizer? authorizer,
    int? maxQueued,
  }) async {
    if (maxQueueWait.isNegative) {
      throw ArgumentError.value(
          maxQueueWait, 'maxQueueWait', 'must be zero or positive');
    }
    if (maxQueued != null && maxQueued < 1) {
      throw ArgumentError.value(
          maxQueued, 'maxQueued', 'must be at least 1');
    }
    if (whitelist != null) {
      _warnUnmatchedWhitelist(bindings, whitelist, onPolicyWarning);
    }

    final muxInput = Cell.ingress<Pulse<WireMessage>>(
      context: inboundContext,
      testRule: WirePulseGate(),
    );

    final inbound = buildInboundCell(context: inboundContext);

    final dispatcher = SkinRouter(
      graph: graph,
      bindings: bindings,
      whitelist: whitelist,
      ledger: ledger,
      descriptions: descriptions,
      strictReceipts: strictReceipts,
      idempotency: idempotency ?? MemoryIdempotencyStore(),
      clock: clock,
      authorizer: authorizer,
    );
    final routerCell = dispatcher.cell(inbound.cell, journal: journal);

    final exposedCellIds = _exposedCellIds(bindings, whitelist);

    // The binding's target and the graph's registered cell must be the
    // same object — otherwise the router and the egress observers
    // would watch different cells.
    for (final binding in bindings.all) {
      final registered = graph[binding.cellId]?.cell;
      if (registered == null) {
        throw StateError('SkinMembrane.open: binding "${binding.cellId}.'
            '${binding.functionName}" targets an unregistered cell');
      }
      if (!identical(registered, binding.target)) {
        throw StateError('SkinMembrane.open: binding "${binding.cellId}.'
            '${binding.functionName}" target is not the graph\'s '
            'registered cell');
      }
    }

    // A bound ledger records every membrane apply, even when the caller
    // did not enter `graph.run` itself: the router opens the graph's
    // ledger scope around each target apply. Egress and `/skin/ledger`
    // follow the membrane's ledger, so the two must be the same object
    // (the one returned by `bindLedger`) or the HTTP tail would never
    // see the rows just appended.
    if (ledger != null && !identical(ledger, graph.ledger)) {
      throw StateError(
        'SkinMembrane.open: ledger must be the graph\'s bound ledger '
        '(the one returned by bindLedger)',
      );
    }

    // positionalNames is a validation zipper: on a closed schema with
    // properties, every name must be a property key — a wrong name can
    // never validate and would fail every positional call at runtime.
    for (final binding in bindings.all) {
      final names = binding.positionalNames;
      final schema = binding.argumentSchema;
      if (names == null || schema == null || schema.properties == null) {
        continue;
      }
      if (schema.additionalProperties == true) continue;
      for (final name in names) {
        if (!schema.properties!.containsKey(name)) {
          throw StateError(
            'SkinMembrane.open: binding "${binding.cellId}.'
            '${binding.functionName}" positionalNames includes "$name", '
            'which is not a property of its argument schema',
          );
        }
      }
    }

    // Unledgered egress: observe the exposed targets directly; every
    // pulse is pendingReceipt (no receipt exists to attach). With a
    // ledger, the tail below drives egress instead — the entry's own
    // receipt pairs with the entry's own payload.
    final egress = ledger == null
        ? buildEgressCells(
            cellIds: exposedCellIds,
            resolveTarget: (cellId) => graph[cellId]?.cell,
            onEgressPulse: (cellId, pulse) => muxInput.emit(pulse),
          )
        : <String, EgressHandle<Pulse>>{};

    // The egress set and the manifest are now frozen — the table must
    // not change under the membrane.
    bindings.seal();

    final sources = <Cell>[routerCell, muxInput.cell];
    StreamSubscription<LedgerEntry>? ledgerSubscription;
    if (ledger != null) {
      // An ingress fed by the ledger tail: `Cell.fromStream` journals
      // each payload as an I/O effect, and the canonical encoder
      // refuses non-JSON wire messages. A plain ingress keeps the
      // ledger stream out of the journal entirely. The same tail
      // drives egress: the entry's own receipt pairs with the entry's
      // own pulse payload — never a borrowed one.
      final ledgerIngress =
          Cell.ingress<WireMessage>(testRule: WirePulseGate());
      ledgerSubscription = ledger.tail.listen((entry) {
        ledgerIngress.emit(WireLedgerEntry(entry: entry));
        if (exposedCellIds.contains(entry.receiptCellId)) {
          // The dispatcher labels rows it applied with the binding's
          // wire name; a miss (replayed history, an inner txApply
          // closure) keeps the stored function text.
          muxInput.emit(Pulse<WireStateChange>(
            wireStateChangeForEntry(
              entry,
              functionLabel: dispatcher.functionLabelFor(entry.receipt.id),
            ),
            type: '${SkinPulseTypes.egressPrefix}${entry.receiptCellId}',
          ));
        }
      });
      sources.add(ledgerIngress.cell);
    }
    final mux = buildMuxCell(sources: sources);

    final events = StreamController<Pulse<WireMessage>>.broadcast();
    final outbound = buildOutboundCell(
        mux: mux,
        send: (pulse) {
          final normalized = _normalizePulseType(pulse);
          if (!events.isClosed) events.add(normalized);
          send(normalized);
        });

    final membrane = SkinMembrane._(
      graph: graph,
      bindings: bindings,
      whitelist: whitelist,
      ledger: ledger,
      inbound: inbound,
      router: routerCell,
      dispatcher: dispatcher,
      egress: egress,
      mux: mux,
      outbound: outbound,
      responses: events.stream,
      events: events,
      ledgerSubscription: ledgerSubscription,
      maxQueueWait: maxQueueWait,
      clock: clock,
      maxQueued: maxQueued,
    );
    dispatcher.onRouted = () {
      membrane._outstanding--;
    };
    return membrane;
  }

  static const Context _defaultInboundContext =
      Context.describe('skin:untrusted');

  static void _warnUnmatchedWhitelist(
    SkinBindingTable bindings,
    SkinWhitelist whitelist,
    void Function(String message)? onPolicyWarning,
  ) {
    if (onPolicyWarning == null) return;
    for (final cellId in whitelist.cellIds) {
      for (final function in whitelist.functionsFor(cellId)) {
        if (bindings.lookup(cellId, function) == null) {
          onPolicyWarning(
              'whitelist entry "$cellId.$function" has no registered '
              'binding (likely a typo)');
        }
      }
    }
    if (whitelist.unlisted == SkinUnlisted.expose) {
      // Only expose mode makes unmentioned bindings reachable; hide is
      // quiet because the binding is not exposed there.
      for (final cellId in bindings.exposedCellIds) {
        if (whitelist.mentionsCell(cellId)) continue;
        for (final binding in bindings.bindingsFor(cellId)) {
          onPolicyWarning(
              'binding "$cellId.${binding.functionName}" is not listed '
              'and will be exposed');
        }
      }
    }
  }

  static List<String> _exposedCellIds(
    SkinBindingTable bindings,
    SkinWhitelist? whitelist,
  ) =>
      [
        for (final cellId in bindings.exposedCellIds)
          if (whitelist == null ||
              bindings
                  .bindingsFor(cellId)
                  .any((b) => whitelist.allows(cellId, b.functionName)))
            cellId,
      ];

  /// Whether any function of [cellId] may cross the skin (binding and
  /// whitelist policy combined).
  bool isExposed(String cellId) =>
      _exposedCellIds(bindings, whitelist).contains(cellId);

  /// Whether [principal] may read [cellId] through the read routes
  /// (manifest, observe, ledger). A `null` authorizer reads everything
  /// exposure allows; a non-null one must allow every binding of the
  /// cell. Not cached.
  Future<bool> mayRead(SkinPrincipal principal, String cellId) =>
      dispatcher.mayRead(principal, cellId);

  /// The current tool catalogue.
  SkinManifest get manifest => SkinManifest.describe(
        graph: graph,
        bindings: bindings,
        whitelist: whitelist,
        descriptions: dispatcher.descriptions,
      );

  /// Emits one wire message into the inbound cell and awaits the
  /// correlated response (a [WireResponse], [WireError] or — for
  /// manifest requests — a [WireManifestResponse]).
  ///
  /// Matching is performed on the request's server-assigned
  /// [WireRequest.correlationId]; egress [WireStateChange] pulses can
  /// never complete a pending request. [context] stamps this request's
  /// provenance on the emitted pulse ([PulseContext.userAction] is the
  /// canonical shape — the [SkinPrincipal]'s bridge output).
  ///
  /// [deadline] is the caller's instant after which a still-queued
  /// request must not start. The earlier of it and `now + maxQueueWait`
  /// wins; with a zero `maxQueueWait` and no [deadline], there is no
  /// queue limit. The existing [timeout] only fails the waiter — it is
  /// never the queue deadline.
  ///
  /// [principal] is the in-process caller: its JSON snapshot is merged
  /// into the emitted context's `others` under `skin.principal` (so the
  /// router can hand it to the authorizer). A caller-supplied [context]
  /// keeps its actor and its other metadata; only `others` gains the
  /// snapshot.
  Future<WireMessage> request(
    WireMessage message, {
    required String type,
    PulseContext? context,
    Duration timeout = const Duration(seconds: 30),
    DateTime? deadline,
    SkinPrincipal? principal,
  }) {
    if (_closed) {
      return Future<WireMessage>.error(
          const SkinError('closed', 'the membrane is closed'));
    }
    if (message is WireNotification) {
      // Notifications have no reply — the router suppresses them, so a
      // request() on one would only ever time out.
      throw ArgumentError(
          'SkinMembrane.request: WireNotification has no response; '
          'emit it through inbound.emit instead');
    }
    // The queue deadline and a possibly-empty correlation id are stamped
    // on a copy of the request; the original object the caller holds is
    // untouched. An empty id is replaced with a fresh one — an empty id
    // cannot identify a retry, and two empty-id requests must never
    // claim the same idempotency key.
    final stamped = message is WireRequest
        ? WireRequest(
            cellId: message.cellId,
            function: message.function,
            positional: message.positional,
            named: message.named,
            correlationId: message.correlationId.isEmpty
                ? nextCorrelationId('skin')
                : message.correlationId,
            clientCorrelationId: message.clientCorrelationId,
            lastSeenSeq: message.lastSeenSeq,
            deadline: _deadlineFor(deadline),
          )
        : message;
    final correlationId = switch (stamped) {
      WireRequest request => request.correlationId,
      WireError error => error.correlationId,
      _ => null,
    };
    final clientId =
        stamped is WireRequest ? stamped.clientCorrelationId : null;
    // The cap counts accepted requests whose dispatch has not finished
    // — the one inside apply occupies a slot. The refused call never
    // claims, never applies, and the in-flight apply still finishes.
    if (_maxQueued != null && _outstanding >= _maxQueued) {
      return Future<WireMessage>.value(WireError(
        correlationId: correlationId ?? '',
        clientCorrelationId: clientId,
        code: 'queue_full',
        message: 'the router queue is full',
      ));
    }
    _outstanding++;
    final matchId =
        (correlationId == null || correlationId.isEmpty) ? null : correlationId;
    final completer = Completer<WireMessage>();
    _pendingRequests.add(completer);
    late final StreamSubscription<Pulse<WireMessage>> subscription;
    subscription = responses.listen((pulse) {
      final payload = pulse.payload;
      if (matchId != null) {
        if (payload is WireResponse && payload.correlationId == matchId ||
            payload is WireError && payload.correlationId == matchId) {
          if (!completer.isCompleted) completer.complete(payload);
          _pendingRequests.remove(completer);
          subscription.cancel();
        }
      } else if (payload is WireManifestResponse) {
        // Manifest responses carry no correlation id: today every
        // in-flight manifest request() completes on the first one. Safe
        // while the manifest is sealed and global; revisit when
        // manifests become principal-specific.
        if (!completer.isCompleted) completer.complete(payload);
        _pendingRequests.remove(completer);
        subscription.cancel();
      }
    });
    inbound.emit(Pulse<WireMessage>.governed(
      payload: stamped,
      type: type,
      context: _withPrincipalSnapshot(context, principal),
    ));
    return completer.future.timeout(timeout, onTimeout: () {
      _pendingRequests.remove(completer);
      subscription.cancel();
      throw TimeoutException('cell_skin: no response for $type', timeout);
    });
  }

  static PulseContext? _withPrincipalSnapshot(
    PulseContext? context,
    SkinPrincipal? principal,
  ) {
    if (principal == null) return context;
    final others = <String, Object?>{
      ...?context?.others,
      'skin.principal': skinPrincipalSnapshot(principal),
    };
    if (context == null) {
      return PulseContext(
        actor: 'skin:${principal.id}',
        others: others,
      );
    }
    // The caller's actor and lineage stay; only `others` gains the
    // snapshot.
    return PulseContext(baseContext: context, others: others);
  }

  DateTime? _deadlineFor(DateTime? caller) {
    final fromQueue = _maxQueueWait == Duration.zero
        ? null
        : _clock().add(_maxQueueWait);
    if (caller == null) return fromQueue;
    if (fromQueue == null) return caller;
    return caller.isBefore(fromQueue) ? caller : fromQueue;
  }

  /// How many requests the router has received but not yet finished
  /// (queued plus the one in flight). For developer panes and tests.
  int get routerQueueDepth => dispatcher.queueDepth;

  /// Whether a dispatch is currently inside the router (0 or 1 under
  /// `concurrency: 1`). For developer panes and tests.
  int get routerInFlight => dispatcher.inFlight;

  /// Whether [close] ran. `/ready` uses this: a closed membrane is not
  /// ready, no matter how healthy the ledger looks.
  bool get isClosed => _closed;

  /// The idempotency store this membrane consults — the memory default,
  /// or the file store the application passed. `/ready` checks a file
  /// store's directory here.
  IdempotencyStore get idempotency => dispatcher.idempotency;

  /// Closes the terminal cell, every egress observer, the receipt
  /// join, the ledger-tail subscription and the response stream, and
  /// fails every pending `request()` with a `closed` [SkinError]. The
  /// router is gated first, so a request that was queued but not yet
  /// dispatching is answered `closed` instead of applying after the
  /// close; an apply already in flight runs to completion (it cannot be
  /// cancelled). The graph and ledger stay open — they belong to the
  /// caller.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    dispatcher.closing = true;
    outbound.stop();
    for (final handle in egress.values) {
      handle.stop();
    }
    egress.clear();
    await _ledgerSubscription?.cancel();
    _ledgerSubscription = null;
    final pending = _pendingRequests.toList();
    _pendingRequests.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(
            const SkinError('closed', 'the membrane was closed'));
      }
    }
    if (!_events.isClosed) await _events.close();
  }
}

Pulse<WireMessage> _normalizePulseType(Pulse<WireMessage> pulse) {
  final type = pulse.type;
  if (type is String && type.isNotEmpty) return pulse;
  // `Cell.fromStream` does not stamp a pulse type; ledger entries are
  // the only source that reaches here without one.
  return Pulse<WireMessage>(
    pulse.payload,
    type: SkinPulseTypes.ledgerEntry,
    source: pulse.source,
  );
}
