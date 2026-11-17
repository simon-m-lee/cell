// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A registered cell graph: the unit of identity and replay in the
/// framework.
///
/// ### When to use
/// As the container the [Ledger] and the [ReplayEngine] operate on. Every
/// graph that is recorded or replayed must first be assembled by
/// [CellGraphBuilder].
///
/// ### How it works
/// A graph's invariants are:
///
/// * **Every cell in the graph has a stable `id`.** Registered cells'
///   nuclei are recorded in `_CellGraphRegistry`; their `id` getter
///   returns the graph-assigned name.
/// * **Every cell is reachable from at least one registered root** via
///   the `bind`/`Synapses` graph, *in strict mode*. Reachability is
///   computed at `build()` time and re-validated lazily.
/// * **No two cells share a name.** Enforced by [CellGraphBuilder].
/// * **Every cell's purity is known.** The journal refuses to record a
///   cell whose receptor and rule are both [Purity.pure] without
///   admitting that journaling is a no-op; the engine refuses to replay
///   an `effectful` cell that was not journalled.
///
/// ### Non-obvious: strict vs. unrestricted
///
/// In strict mode (the default), the graph enforces reachability and
/// refuses to bind a cell that is not registered — see
/// `_validateBindTarget`. `CellGraph.unrestricted()` disables these
/// checks for tests; it is documented as unsafe and marked
/// `@visibleForTesting`.
///
/// ### Non-obvious: the graph does not own the cells
///
/// The graph is a *view*, not a container. It holds references to the
/// cells (so they cannot be garbage-collected while the graph is alive),
/// but it does not `dispose` them, and a `cell` obtained from outside the
/// graph continues to function after the graph is dropped. That is
/// deliberate — the graph is metadata, not a lifecycle manager. The
/// lifecycle manager is [EphemeralPolicy] (the journal hooks into it).
///
/// See also:
/// * [CellGraphBuilder] — how a graph is assembled.
/// * [Ledger] — the history a graph is bound to.
/// * [ReplayEngine] — the engine that replays into a graph.
/// {@category Replay}
class CellGraph {
  final String graphId;
  final bool strict;
  final List<RegisteredCell> _registered;
  final Map<String, RegisteredCell> _byName;

  CellGraph._({
    required this.graphId,
    required this.strict,
    required List<RegisteredCell> registered,
    required Map<String, RegisteredCell> byName,
  })  : _registered = registered,
        _byName = byName;

  /// The entry point for constructing a registered graph. See
  /// [CellGraphBuilder].
  static CellGraphBuilder builder({String? graphId, bool strict = true}) =>
      CellGraphBuilder(graphId: graphId, strict: strict);

  /// Convenience factory for tests and for `CellGraph.unrestricted()`.
  ///
  /// Unrestricted graphs skip the strict reachability and bind-target
  /// checks. Documented as unsafe for production.
  @visibleForTesting
  factory CellGraph.unrestricted({String? graphId}) {
    return CellGraphBuilder(graphId: graphId, strict: false).build();
  }

  /// The graph's id. Stable across processes if supplied to the builder.
  String get id => graphId;

  /// The list of registered roots (in registration order).
  List<RegisteredCell> get roots => List.unmodifiable(_registered);

  /// Look up a registered cell by name.
  RegisteredCell? operator [](String name) => _byName[name];

  /// Whether [name] is registered in this graph.
  bool containsName(String name) => _byName.containsKey(name);

  /// Whether [cell] is registered in this graph (by identity — deputies
  /// that share a principal's id are considered *different* cells and
  /// are not equal by this method unless they share the same name).
  bool containsCell(Cell cell) => _byName.containsKey(cell.id);

  /// The purity of a registered cell, computed from its receptor and
  /// test rule. Both must be [Purity.pure] for the cell to report
  /// [Purity.pure]; otherwise the *weaker* (more external) of the two
  /// wins.
  ///
  /// [Receptor.purity] and [TestCell.purity]
  /// default to `pure` today; the journal layer populates them. The method
  /// exists now so callers can already query it and so tests can assert
  /// the invariant holds.
  Purity purityOf(String name) {
    final registered = _byName[name];
    if (registered == null) {
      throw ArgumentError.value(name, 'name', 'is not registered');
    }
    final receptor = registered.cell._nucleus.receptor;
    final rule = registered.cell._nucleus.testRule;
    return _weaker(receptor.purity, rule.purity);
  }

  static Purity _weaker(Purity a, Purity b) {
    // Purity orders from most replayable to least: pure < readOnlyExternal
    // < effectful. The "weaker" (more external) classification wins.
    return a.index >= b.index ? a : b;
  }

  /// The set of pulse sources the graph recognizes. Used by the journal to
  /// enforce that a journalled pulse's `source` is a registered cell.
  Set<String> get registeredIds => Set.unmodifiable(_byName.keys);

  // ── ledger ───────────────────────────────────────────────────────────

  Ledger? _ledger;

  /// The ledger this graph is bound to, or `null` if the graph is not
  /// ledgered. A graph can have at most one ledger; call `unbindLedger`
  /// to sever the binding before binding a different one.
  Ledger? get ledger => _ledger;

  /// Binds this graph to a new ledger backed by [store]. Runs
  /// `Ledger.openVerified` so a corrupt store fails at bind time, not on
  /// first append.
  ///
  /// ### How it works
  /// Every subsequent `Cell.apply` / `ValueCell.update` on a cell in this
  /// graph — inside [run] — is recorded in the ledger. Binding is
  /// **idempotent**: if the graph is already bound, throws [StateError] —
  /// a graph cannot have two ledgers, and silently swapping would leave
  /// the old ledger permanently incomplete.
  ///
  /// ### Parameters:
  /// - [store]: The persistence backend for the new ledger.
  ///
  /// ### Returns:
  /// The opened and verified ledger.
  Future<Ledger> bindLedger({required LedgerStore store}) async {
    if (_ledger != null) {
      throw StateError(
        'CellGraph.bindLedger: graph "$graphId" is already bound to a '
        'ledger. Call unbindLedger first if you intend to swap.',
      );
    }
    final ledger = await Ledger.openVerified(graph: this, store: store);
    _ledger = ledger;
    return ledger;
  }

  /// Severs the graph's binding to its ledger. The ledger remains open
  /// (the caller must close it); subsequent `Cell.apply` calls on the
  /// graph are no longer recorded.
  ///
  /// ### Returns:
  /// The previously bound ledger, or `null` if the graph was not bound.
  Future<Ledger?> unbindLedger() async {
    final l = _ledger;
    _ledger = null;
    return l;
  }

  /// Runs [body] with this graph's ledger scope active. All
  /// `Cell.apply`/`ValueCell.update` calls inside [body] are recorded,
  /// and the scope's queued appends are drained before this resolves.
  ///
  /// ### Parameters:
  /// - [body]: The work to run under the ledger scope.
  ///
  /// ### Returns:
  /// The body's result, after the scope's queued appends have drained.
  Future<T> run<T>(FutureOr<T> Function() body) {
    final l = _ledger;
    if (l == null) {
      throw StateError(
        'CellGraph.run: graph "$graphId" is not bound to a ledger. '
        'Call bindLedger(...) first.',
      );
    }
    return LedgerScope.run(LedgerScopeImpl(ledger: l), body);
  }

  // ── validation ──────────────────────────────────────────────────────

  /// Walks every registered root's descendants (via `bind` and
  /// `Synapses`) and rejects any cell reached through a **bind edge** that
  /// is not registered. Called at `build()` time so the failure is
  /// immediate, and again from `_validateBindTarget` whenever a new bind
  /// is observed at runtime.
  ///
  /// The violation rule is deliberately scoped to `bind` edges: that is
  /// the user-facing wiring surface and the graph's acceptance criterion
  /// ("unregistered bind in a graph is rejected"). Synapse edges are how
  /// the framework wires operator internals (e.g. `asyncMap`'s internal
  /// bridge cell, terminal observers), which users cannot register; those
  /// are traversed for completeness but are the journal's concern.
  ///
  /// In unrestricted mode, this method does nothing.
  void _validateReachability() {
    if (!strict) return;
    final seen = <String>{};
    final pending = <Cell>[
      for (final r in _registered) r.cell,
    ];
    while (pending.isNotEmpty) {
      final cell = pending.removeLast();
      final id = cell.id;
      if (!seen.add(id)) continue;

      // Enumerate bind + synapses. `_nucleus.bind` gives the direct
      // upstream; `_nucleus.synapses` iterates downstreams. Only bind
      // targets are checked against the registry.
      final upstream = cell._nucleus.bind;
      if (upstream != null) {
        if (!containsName(upstream.id)) {
          throw StateError(
            'CellGraph reachability violation: cell "${upstream.id}" is '
            'bound as the upstream of registered cell "$id", but is not '
            'registered. Register it with CellGraphBuilder.register(), '
            'or use CellGraph.unrestricted() for tests.',
          );
        }
        pending.add(upstream);
      }
      for (final downstream in cell._nucleus.synapses) {
        pending.add(downstream);
      }
    }
  }

  // Runtime bind gate; the journal wires it into synapse linking so late
  // binds are checked as they happen.
  // ignore: unused_element
  void _validateBindTarget(Cell bind) {
    if (!strict) return;
    if (!containsName(bind.id)) {
      throw StateError(
        'CellGraph strict mode: binding to a cell whose id is "${bind.id}" '
        'which is not registered in graph "$graphId". Register it first, '
        'or use CellGraph.unrestricted() for tests.',
      );
    }
  }

  // ── snapshot ─────────────────────────────────────────────────────────

  /// Produces a [CellGraphSnapshot] of the current cell states.
  ///
  /// ### Non-obvious: JSON-encodable values only
  ///
  /// The snapshot serialises only the JSON-encodable value of each cell.
  /// `ValueCell` values that are not JSON-encodable require the user to
  /// register a payload codec (the journal adds this). A snapshot of a
  /// `ValueCell<int>` or `ValueCell<String>` works; anything else throws.
  ///
  /// ### Parameters:
  /// - [lastLedgerSeq]: The ledger position the snapshot is taken at.
  /// - [parentLedgerHash]: The ledger's hash up to that position.
  ///
  /// ### Returns:
  /// The snapshot. [lastLedgerSeq] and [parentLedgerHash] are ledger
  /// concerns; the graph takes them as arguments so the snapshot's *shape*
  /// is final and the ledger only needs to populate them.
  CellGraphSnapshot snapshot({
    int lastLedgerSeq = -1,
    String? parentLedgerHash,
  }) {
    final cells = <CellSnapshot>[];
    for (final registered in _registered) {
      final cell = registered.cell;
      final value = _snapshotValue(cell);
      final receptor = cell._nucleus.receptor;
      final rule = cell._nucleus.testRule;
      final receptorVersion = _receptorVersion(cell);
      cells.add(CellSnapshot(
        id: registered.name,
        configFingerprint: fingerprint({
          'receptor': _receptorName(receptor),
          'receptorVersion': receptorVersion,
          'purity': receptor.purity.name,
          'testRule': _ruleName(rule),
          'context': cell.context.taxonomy ?? '',
        }),
        receptorVersion: receptorVersion,
        value: value,
      ));
    }
    // Sort by id so two graphs with the same cells produce the same
    // snapshot bytes regardless of registration order.
    cells.sort((a, b) => a.id.compareTo(b.id));
    return CellGraphSnapshot(
      graphId: graphId,
      schemaVersion: CellGraphSnapshot.currentSchemaVersion,
      lastLedgerSeq: lastLedgerSeq,
      parentLedgerHash: parentLedgerHash,
      cells: cells,
    );
  }

  Object? _snapshotValue(Cell cell) {
    if (cell is ValueCell) {
      // Review fix: encode with the SAME codec the ledger deltas use
      // (`_encodeForLedger`) instead of storing the raw `cell.value` —
      // a DateTime or other non-JSON live value used to throw inside
      // canonicalJsonEncode when the snapshot was fingerprinted (e.g.
      // the fork's originalSnapshotHash). JSON types pass through
      // unchanged.
      return ValueCell._encodeForLedger(cell.value);
    }
    // Non-ValueCell cells (ingress, derived, hub, etc.) have no
    // persistent state, so they snapshot to `null`. The snapshot still
    // records their config fingerprint so the engine can detect a
    // reconfiguration.
    return null;
  }

  String _receptorVersion(Cell cell) {
    // Default: `0.0.0` until the journal layer stamps the actual version.
    // The version string is what gets stored in the ledger; the engine
    // uses it to dispatch to the correct receptor implementation.
    return cell._nucleus.receptor.version;
  }

  String _receptorName(Receptor receptor) {
    // A stable name for the receptor. The journal layer overrides this with a
    // registered name; the fallback is `runtimeType`, which is at
    // least stable within a Dart VM.
    return receptor.runtimeType.toString();
  }

  String _ruleName(TestCell rule) {
    return rule.runtimeType.toString();
  }

  @override
  String toString() =>
      'CellGraph(id: $graphId, roots: ${_registered.length}, '
      'strict: $strict)';
}
