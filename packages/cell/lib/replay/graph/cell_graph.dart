// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A registered cell graph: the unit of identity and replay in the
/// framework.
///
/// A [CellGraph] is the *container* that Phase 4's `Ledger` and Phase 5's
/// `ReplayEngine` operate on. Its invariants are:
///
/// * **Every cell in the graph has a stable `id`.** Registered cells'
///   nuclei are recorded in `_CellGraphRegistry`; their `id` getter
///   returns the graph-assigned name.
/// * **Every cell is reachable from at least one registered root** via
///   the `bind`/`Synapses` graph, *in strict mode*. Reachability is
///   computed at `build()` time and re-validated lazily.
/// * **No two cells share a name.** Enforced by `CellGraphBuilder`.
/// * **Every cell's purity is known.** Phase 3 will refuse to journal a
///   cell whose receptor and rule are both [Purity.pure] without
///   admitting that journaling is a no-op; Phase 5 will refuse to replay
///   an `effectful` cell that was not journalled.
///
/// ### Strict vs. unrestricted
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
/// lifecycle manager is [EphemeralPolicy] (Phase 3 will hook into it).
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
  /// This is a Phase 2 stub: [Receptor.purity] and [TestCell.purity]
  /// default to `pure` today, and Phase 3 will populate them. The method
  /// exists now so callers can already query it and so tests can assert
  /// the invariant holds as Phase 3 lands.
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

  /// The set of pulse sources the graph recognizes. Used by Phase 3 to
  /// enforce that a journalled pulse's `source` is a registered cell.
  Set<String> get registeredIds => Set.unmodifiable(_byName.keys);

  // ── validation ──────────────────────────────────────────────────────

  /// Walks every registered root's descendants (via `bind` and
  /// `Synapses`) and rejects any cell that is not registered. Called at
  /// `build()` time so the failure is immediate, and again from
  /// `_validateBindTarget` whenever a new bind is observed at runtime.
  ///
  /// In strict mode, this is the enforcement that makes a graph
  /// *replayable*: an unregistered downstream cell is a cell whose
  /// receptor might not be journalled and whose state might not be
  /// snapshotted. If we allowed it, replay would silently miss part of
  /// the graph.
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
      if (!containsName(id)) {
        throw StateError(
          'CellGraph reachability violation: cell "$id" was reached via '
          'the bind/synapse graph from a registered root, but is not '
          'registered. Register it with CellGraphBuilder.register(), '
          'or use CellGraph.unrestricted() for tests.',
        );
      }
      // Enumerate bind + synapses. `_nucleus.bind` gives the direct
      // upstream; `_nucleus.synapses` iterates downstreams.
      final upstream = cell._nucleus.bind;
      if (upstream != null) pending.add(upstream);
      for (final downstream in cell._nucleus.synapses) {
        pending.add(downstream);
      }
    }
  }

  // Runtime bind gate; Phase 3+ wires it into synapse linking so late
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
  /// **Phase 1 limitation:** the snapshot serialises only the JSON-
  /// encodable value of each cell. `ValueCell` values that are not
  /// JSON-encodable require the user to register a payload codec (Phase 3
  /// adds this). For Phase 2, a snapshot of a `ValueCell<int>` or
  /// `ValueCell<String>` works; anything else throws.
  ///
  /// [lastLedgerSeq] and [parentLedgerHash] are Phase 4 concerns; Phase 2
  /// takes them as arguments so the snapshot's *shape* is final and Phase 4
  /// only needs to populate them.
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
      // ValueCell<V>.value is V?; the caller's V may not be JSON-
      // encodable. Canonical encoder throws loudly on failure, which is
      // the right behaviour — Phase 3's payload codec registration will
      // give the caller a place to plug in their own.
      return cell.value;
    }
    // Non-ValueCell cells (ingress, derived, hub, etc.) have no
    // persistent state, so they snapshot to `null`. The snapshot still
    // records their config fingerprint so Phase 5 can detect a
    // reconfiguration.
    return null;
  }

  String _receptorVersion(Cell cell) {
    // Phase 2 default: `0.0.0` until Phase 3 stamps the actual version.
    // The version string is what gets stored in the ledger; Phase 5
    // uses it to dispatch to the correct receptor implementation.
    return cell._nucleus.receptor.version;
  }

  String _receptorName(Receptor receptor) {
    // A stable name for the receptor. Phase 3 will override this with a
    // registered name; Phase 2 falls back to `runtimeType`, which is at
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
