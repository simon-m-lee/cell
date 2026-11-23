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
import '../wire/wire_message.dart';
import 'egress_cell.dart';
import 'inbound_cell.dart';
import 'mux_cell.dart';
import 'router_cell.dart';

/// The four-Cell membrane between a [CellGraph] and the wire.
///
/// ### When to use
/// * Every transport: REST, MCP, and Dart clients share this one
///   assembled pipeline — never build a second dispatch path.
///
/// ### How it works
/// [SkinMembrane.open] composes `Cell.ingress` → `Cell.asyncMap`
/// (`concurrency: 1`) → `target.apply` → egress → mux → outbound over
/// the graph, an optional ledger, and a transport writer. [request]
/// awaits the correlated [WireResponse]/[WireError]; [responses]
/// broadcasts everything that survives the mux.
///
/// ### Non-obvious
/// The binding table seals at [SkinMembrane.open]: the egress set and
/// the manifest can never diverge afterwards. Egress is
/// [WireStateChange], never a reply; a pending `request()` is only ever
/// completed by its own correlated response/error.
///
/// ### See also
/// [SkinRouter] (the dispatch brain), [SkinBindingTable], [SkinClient],
/// and `ARCHITECTURE-Skin.md` §2.
/// {@category Membrane}
final class SkinMembrane {
  /// The graph being skinned.
  final CellGraph graph;

  /// The exposure registry. Sealed at [SkinMembrane.open] — the egress
  /// cells and the manifest can never diverge.
  final SkinBindingTable bindings;

  /// The declarative exposure policy, when configured.
  final SkinWhitelist? whitelist;

  /// The graph's ledger, when one is bound.
  final Ledger? ledger;

  /// Cell 1 — inbound: transport pulses enter here.
  final IngressHandle<Pulse<WireMessage>> inbound;

  /// Cell 2 — router: binding lookup, cursor check, `target.apply`.
  final Cell router;

  /// The dispatch brain behind [router].
  final SkinRouter dispatcher;

  /// Cell 3 — egress: one `Cell.observe` per exposed target.
  final Map<String, EgressHandle<Pulse>> egress;

  /// The fan-in primitive.
  final Cell mux;

  /// Cell 4 — outbound: the terminal cell writing to the transport.
  final EgressHandle<Pulse<WireMessage>> outbound;

  /// The receipt join for egress pulses.

  /// Every pulse that survives the mux, as a broadcast stream (router
  /// responses, egress observations, ledger entries, errors).
  final Stream<Pulse<WireMessage>> responses;

  final StreamController<Pulse<WireMessage>> _events;
  StreamSubscription<LedgerEntry>? _ledgerSubscription;
  final Set<Completer<WireMessage>> _pendingRequests = {};
  bool _closed = false;

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
  })  : _events = events,
        _ledgerSubscription = ledgerSubscription;

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
  /// **Live signature:** `static Future<SkinMembrane> open({required CellGraph graph, required SkinBindingTable bindings, SkinWhitelist? whitelist, Ledger? ledger, required EffectJournal journal, required void Function(Pulse<WireMessage>) send, Context inboundContext, Map<String, String>? descriptions, void Function(String)? onPolicyWarning})` — pinned at `cell_skin: 0.1.0`
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
  ///   ..register(SkinBinding(
  ///     cellId: 'thermostat',
  ///     functionName: 'setTarget',
  ///     target: thermostat.cell,
  ///     function: (int target) => thermostat.update(target),
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
  }) async {
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
          muxInput.emit(Pulse<WireStateChange>(
            wireStateChangeForEntry(entry),
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

    return SkinMembrane._(
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
    );
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
  Future<WireMessage> request(
    WireMessage message, {
    required String type,
    PulseContext? context,
    Duration timeout = const Duration(seconds: 30),
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
    final correlationId = switch (message) {
      WireRequest request => request.correlationId,
      WireError error => error.correlationId,
      _ => null,
    };
    final completer = Completer<WireMessage>();
    _pendingRequests.add(completer);
    late final StreamSubscription<Pulse<WireMessage>> subscription;
    subscription = responses.listen((pulse) {
      final payload = pulse.payload;
      if (correlationId != null) {
        if (payload is WireResponse && payload.correlationId == correlationId ||
            payload is WireError && payload.correlationId == correlationId) {
          if (!completer.isCompleted) completer.complete(payload);
          _pendingRequests.remove(completer);
          subscription.cancel();
        }
      } else if (payload is WireManifestResponse) {
        if (!completer.isCompleted) completer.complete(payload);
        _pendingRequests.remove(completer);
        subscription.cancel();
      }
    });
    inbound.emit(Pulse<WireMessage>.governed(
      payload: message,
      type: type,
      context: context,
    ));
    return completer.future.timeout(timeout, onTimeout: () {
      _pendingRequests.remove(completer);
      subscription.cancel();
      throw TimeoutException('cell_skin: no response for $type', timeout);
    });
  }

  /// Closes the terminal cell, every egress observer, the receipt
  /// join, the ledger-tail subscription and the response stream, and
  /// fails every pending `request()` with a `closed` [SkinError]. The
  /// graph and ledger stay open — they belong to the caller.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
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
